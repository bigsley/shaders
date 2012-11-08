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
uniform sampler2D webcam;

void main() {
  gl_FragColor = vec4(0., 0., 0., 1.);
}
"""

compileShader = (gl, shaderSource, shaderType) ->
  shader = gl.createShader(shaderType)
  gl.shaderSource(shader, shaderSource)
  gl.compileShader(shader)
  return shader

getShaderError = (gl, shader) ->
  compiled = gl.getShaderParameter(shader, gl.COMPILE_STATUS)
  return gl.getShaderInfoLog(shader) if !compiled

bufferAttribute = (gl, program, attrib, data, size=2) ->
  location = gl.getAttribLocation(program, attrib)
  buffer = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW)
  gl.enableVertexAttribArray(location)
  gl.vertexAttribPointer(location, size, gl.FLOAT, false, 0, 0)

streaming = false


window.GLRenderer = Backbone.View.extend
  initialize: (args) ->
    @el = args['el']
    @startTime = Date.now()
    this.initializeRenderer()
    this.draw()

  draw: (uniforms={}) ->
    this.updateVideo()

    # set uniforms
    for own name, value of uniforms
      location = @gl.getUniformLocation(@program, name)
      if typeof value == "number"
        value = [value]
      switch value.length
        when 1 then @gl.uniform1fv(location, value)
        when 2 then @gl.uniform2fv(location, value)
        when 3 then @gl.uniform3fv(location, value)
        when 4 then @gl.uniform4fv(location, value)

    # draw
    @gl.drawArrays(@gl.TRIANGLES, 0, 6)

  initializeRenderer: ->
    @gl = @el[0].getContext("experimental-webgl", {premultipliedAlpha: false})
    @program = @gl.createProgram()
    @shaders = {} # used to keep track of the shaders we've attached to program, so that we can detach them later
    @shaders[@gl.VERTEX_SHADER] = compileShader(@gl, vertexShaderSource, @gl.VERTEX_SHADER)
    @shaders[@gl.FRAGMENT_SHADER] = compileShader(@gl, fragmentShaderSource, @gl.FRAGMENT_SHADER)
    @gl.attachShader(@program, @shaders[@gl.VERTEX_SHADER])
    @gl.attachShader(@program, @shaders[@gl.FRAGMENT_SHADER])
    @gl.linkProgram(@program)
    @gl.useProgram(@program)
    bufferAttribute(@gl, @program, "vertexPosition", [
      -1.0, -1.0,
       1.0, -1.0,
      -1.0,  1.0,
      -1.0,  1.0,
       1.0, -1.0,
       1.0,  1.0
    ])

    this.createTexture()
    window.URL = window.URL || window.webkitURL || window.mozURL || window.msURL
    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia

    @video = null
    if !@video
      @video = document.createElement( 'video' )
      @video.width = 640
      @video.height = 480
      
      askForCamWrapper = =>
        @askForCam()
      # Sometimes the browser doesn't ask for the webcam if it happens too fast.. so there's this silly delay
      setTimeout(askForCamWrapper, 200)
      # this.askForCam()

    this.updateVideo()

    update = () =>
      this.draw
        time: (Date.now() - @startTime)/1000
        
      window.webkitRequestAnimationFrame(update)

    update()

  askForCam: () ->
    success = (stream) =>
      console.log "received stream"
      if (navigator.mozGetUserMedia != undefined )
        @video.src = stream
      else
        @video.src = window.URL.createObjectURL(stream)
      @video.play()
      streaming = true

      this.updateVideo()
  
    error = (err) =>
      alert('Webcam required')
      console.log(err)
    
    navigator.getUserMedia({video: true}, success, error)

  updateVideo: () ->
    if streaming && @video.readyState == 4
      @gl.activeTexture(@gl.TEXTURE0)
      @gl.bindTexture(@gl.TEXTURE_2D, @texture)
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, @video) 
      this.hackSetUniformInt("webcam", 0)

  replaceShader: (shaderSource, shaderType) ->
    shader = compileShader(@gl, shaderSource, shaderType)
    err = getShaderError(@gl, shader)
    if err
      @gl.deleteShader(shader)
      return err
    else
      # detach and delete old shader
      @gl.detachShader(@program, @shaders[shaderType])
      @gl.deleteShader(@shaders[shaderType])

      # attach new shader, keep track of it in shaders
      @gl.attachShader(@program, shader)
      @shaders[shaderType] = shader

      return null

  loadFragmentShader: (shaderSource) ->
    this.replaceShader(shaderSource, @gl.FRAGMENT_SHADER)

  link: () ->
    @gl.linkProgram(@program)
    # TODO check for errors
    return null

  createTexture: (image) ->
    @texture = @gl.createTexture()
    @gl.bindTexture(@gl.TEXTURE_2D, @texture)

    # Set the parameters so we can render any size image.
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_WRAP_S, @gl.CLAMP_TO_EDGE)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_WRAP_T, @gl.CLAMP_TO_EDGE)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_MIN_FILTER, @gl.NEAREST)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_MAG_FILTER, @gl.NEAREST)

    if image
      # Upload the image into the texture.
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, image)

  hackSetUniformInt: (name, value) ->
    location = @gl.getUniformLocation(@program, name)
    @gl.uniform1i(location, value)

