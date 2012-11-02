vertexShaderSource = """
precision mediump float;

attribute vec3 vertexPosition;
varying vec2 position;

void main() {
  gl_Position = vec4(vertexPosition, 1.0);
  position = (vertexPosition.xy + 1.0) * 0.5;
}
"""


fragmentShaderSource = """
precision mediump float;

varying vec2 position;

void main() {
  gl_FragColor = vec4(1., 0.4, 0.5, 1.);
}
"""

componentToHex = (c) ->
  hex = (c).toString(16)
  if hex.length == 1
    "0" + hex
  else
    hex

rgbToHex = (r, g, b) ->
  "#" + componentToHex(r) + componentToHex(g) + componentToHex(b)

hexToRgb = (hex) ->
  result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if result
    { r: parseInt(result[1], 16), g: parseInt(result[2], 16), b: parseInt(result[3], 16) }
  else
    null

window.hexToRgb = hexToRgb

rgbToArgs = (obj) ->
  "#{obj.r / 256.0}, #{obj.g / 256.0}, #{obj.b / 256.0}"

window.rgbToArgs = rgbToArgs

GLRenderer = Backbone.View.extend
  initialize: (args) ->
    @el = args['el']
    glContext = $('#canvas')[0].getContext("experimental-webgl", {premultipliedAlpha: false})
    makeFlatRenderer(glContext).draw()

  events:
    'click .add_picker': 'addPicker'
    'click .remove_picker': 'removePicker'
    'click .color': 'showPicker'
    'keyup .time': 'updateCode'
    'keyup .color': 'updateColor'

  addPicker: (e) ->
    e.preventDefault()

    clonedPicker = $($('.picker')[0]).clone()
    $('.pickers').append(clonedPicker)

  removePicker: (e) ->
    e.preventDefault()

  showPicker: (e) ->
    $('#ColorPicker').remove()
    target = $(e.target).closest('.color')
    picker = new Color.Picker
      autoclose: true
      color: '#FFFFFF'
      callback: (rgba) =>
        hex = rgbToHex(rgba.R, rgba.G, rgba.B)
        target.val(hex)
        this.updateDivColor(target, hex)

    picker.element.style.top = target.position().top + "px"
    picker.element.style.left = target.position().left + target.width() + 20 + "px"
    $(picker.element).show()

  updateColor: (e) ->
    target = $(e.target).closest('.color')
    color = target.val()
    this.updateDivColor(target, color)

  updateDivColor: (target, color) ->
    target.css('background-color', color)
    rgb = hexToRgb(color)

    if rgb
      if (rgb.r + rgb.g + rgb.b < (256.0 * 1.5))
        target.css('color', '#fff')
      else
        target.css('color', '#000')

    this.updateCode()


  updateCode: ->
    colors = []
    times = []
    displayTimes = []
    functionName = $('.function_name').val()
    code = "vec3 #{functionName}(float val) {\n"
    $('.picker').each (index, element) ->
      color = hexToRgb($(element).find('.color').val())
      time = parseFloat($(element).find('.time').val())
      if color? && time? && time >= 0.0 && time <= 1.0
        colors.push(color)
        times.push(time)
        displayTimes.push(time.toFixed(5))

    # assume the times are sorted
    if colors.length == 1
      code += "\treturn vec3(#{rgbToArgs(colors[0])});\n"
    else
      for i in [0...colors.length]
        if i == 0
          code += "\tif (val < #{displayTimes[i]}) {\n"
          code += "\t return vec3(#{rgbToArgs(colors[i])});\n"

        if i == colors.length - 1
          code += "\t} else {\n"
          code += "\t\treturn vec3(#{rgbToArgs(colors[i])});\n"
          code += "\t}\n"
        else
          time1 = times[i]
          time2 = times[i + 1]
          diff = time2 - time1
          displayTime1 = displayTimes[i]
          displayTime2 = displayTimes[i + 1]
          displayDiff = diff.toFixed(5)
          code += "\t} else if (val >= #{displayTime1} && val < #{displayTime2}) {\n"
          code += "\t\tfloat param = ((val - #{displayTime1}) / #{displayDiff});\n"
          code += "\t\tvec3 color_1 = vec3(#{rgbToArgs(colors[i])});\n"
          code += "\t\tvec3 color_2 = vec3(#{rgbToArgs(colors[i + 1])});\n"
          code += "\t\treturn mix(color_1, color_2, param);\n"

    code += "}"
    $('.code').val(code)

  compileShader: (gl, shaderSource, shaderType) ->
    shader = gl.createShader(shaderType)
    gl.shaderSource(shader, shaderSource)
    gl.compileShader(shader)
    return shader

  getShaderError: (gl, shader) ->
    compiled = gl.getShaderParameter(shader, gl.COMPILE_STATUS)
    return gl.getShaderInfoLog(shader) if !compiled

  bufferAttribute: (gl, program, attrib, data, size=2) ->
    location = gl.getAttribLocation(program, attrib)
    buffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW)
    gl.enableVertexAttribArray(location)
    gl.vertexAttribPointer(location, size, gl.FLOAT, false, 0, 0)


  initializeFlatRenderer: (gl) ->
    program = gl.createProgram()
    shaders = {} # used to keep track of the shaders we've attached to program, so that we can detach them later
    shaders[gl.VERTEX_SHADER] = compileShader(gl, vertexShaderSource, gl.VERTEX_SHADER)
    shaders[gl.FRAGMENT_SHADER] = compileShader(gl, fragmentShaderSource, gl.FRAGMENT_SHADER)
    gl.attachShader(program, shaders[gl.VERTEX_SHADER])
    gl.attachShader(program, shaders[gl.FRAGMENT_SHADER])
    gl.linkProgram(program)
    gl.useProgram(program)
    bufferAttribute(gl, program, "vertexPosition", [
      -1.0, -1.0,
       1.0, -1.0,
      -1.0,  1.0,
      -1.0,  1.0,
       1.0, -1.0,
       1.0,  1.0
    ])

  replaceShader: (shaderSource, shaderType) ->
    shader = compileShader(gl, shaderSource, shaderType)
    err = getShaderError(gl, shader)
    if err
      gl.deleteShader(shader)
      return err
    else
      # detach and delete old shader
      gl.detachShader(program, shaders[shaderType])
      gl.deleteShader(shaders[shaderType])

      # attach new shader, keep track of it in shaders
      gl.attachShader(program, shader)
      shaders[shaderType] = shader

      return null

  flatRenderer = {
    loadFragmentShader: (shaderSource) ->
      replaceShader(shaderSource, gl.FRAGMENT_SHADER)

    link: () ->
      gl.linkProgram(program)
      # TODO check for errors
      return null

    createTexture: (image) ->
      texture = gl.createTexture()
      gl.bindTexture(gl.TEXTURE_2D, texture)

      # Set the parameters so we can render any size image.
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

      # Upload the image into the texture.
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)

      return texture

    readPixels: () ->
      flatRenderer.draw()
      w = gl.drawingBufferWidth
      h = gl.drawingBufferHeight
      arr = new Uint8Array(w * h * 4)
      gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, arr)
      return arr

    draw: (uniforms={}) ->
      # set uniforms
      for own name, value of uniforms
        location = gl.getUniformLocation(program, name)
        if typeof value == "number"
          value = [value]
        switch value.length
          when 1 then gl.uniform1fv(location, value)
          when 2 then gl.uniform2fv(location, value)
          when 3 then gl.uniform3fv(location, value)
          when 4 then gl.uniform4fv(location, value)

      # draw
      gl.drawArrays(gl.TRIANGLES, 0, 6)
  }

  return flatRenderer

$ ->
  # glContext = $('#canvas')[0].getContext("experimental-webgl", {premultipliedAlpha: false})
  # makeFlatRenderer(glContext).draw()
  new GLRenderer({el: $('.color_schemer')})
