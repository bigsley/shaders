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

ShaderMaker = Backbone.View.extend
  initialize: (args) ->
    @el = args['el']
    @gradient_renderer = args['gradient_renderer']
    @transformed_renderer = args['transformed_renderer']

  events:
    'click .add_picker': 'addPicker'
    'click .remove_picker': 'removePicker'
    'click .color': 'showPicker'
    'keyup .time': 'updateCode'
    'keyup .color': 'updateColor'
    'keyup .function_name': 'updateCode'
    'click .canvases canvas': 'growShrinkCanvas'
    'click .animate': 'animate'
    'click .import_random': 'importRandom'

  growShrinkCanvas: (e) ->
    $(e.target).closest('canvas').toggleClass('blowup')

  addPicker: (e) ->
    e.preventDefault() if e

    pickerHTML = """
      <div class='picker'>
        <input class='color' type='text'>
        <input class='time' type='text'>
      </div>"""

    $('.pickers').append(pickerHTML)

  setNumberPickers: (num) ->
    $('.pickers').find('.picker').each (x, elem) ->
      $(elem).remove()

    this.addPicker() for [1..num]

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
        this.updateCode()

    picker.element.style.top = target.position().top + "px"
    picker.element.style.left = target.position().left + target.width() + 20 + "px"
    $(picker.element).show()

  updateColor: (e) ->
    target = $(e.target).closest('.color')
    color = target.val()
    this.updateDivColor(target, color)
    this.updateCode()

  updateDivColor: (target, color) ->
    target.css('background-color', color)
    rgb = hexToRgb(color)

    if rgb
      if (rgb.r + rgb.g + rgb.b < (256.0 * 1.5))
        target.css('color', '#fff')
      else
        target.css('color', '#000')

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
          code += "\t\treturn vec3(#{rgbToArgs(colors[i])});\n"

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
    this.getFullProgram()
    this.getTransformedProgram()


  getFullProgram: ->
    func = $('.code').val()
    func_name = $('.function_name').val()
    code = """
      precision mediump float;

      varying vec2 position;

      #{func}
      
      void main() {
        gl_FragColor = vec4(#{func_name}(position.x), 1.);
      }"""
    @gradient_renderer.loadFragmentShader(code)
    @gradient_renderer.link()
    @gradient_renderer.draw()

  getTransformedProgram: ->
    func = $('.code').val()
    func_name = $('.function_name').val()

    animateCode =
      if @doAnimate
        "v = mod(v + mod(time / 10., 1.), 1.);"
      else
        ""

    transformed_program = """
      precision mediump float;

      varying vec2 position;
      uniform sampler2D webcam;
      uniform float time;

      #{func}

      void main() {
        vec2 pos = vec2(position.x, 1. - position.y);
        vec4 color = texture2D(webcam, pos);
        float v = max(color.x, max(color.y, color.z));
        #{animateCode}
        gl_FragColor = vec4(#{func_name}(v), 1.);
      }"""
    @transformed_renderer.loadFragmentShader(transformed_program)
    @transformed_renderer.link()
    @transformed_renderer.draw()

  animate: (e) ->
    @doAnimate = $(e.target).closest('.animate').is(":checked")
    this.updateCode()

  importRandom: ->
    $('.function_name').val('random_func') if $('.function_name').val().trim() == ""


    callback = (args) =>
      colors = args[0]["colors"]
      this.setNumberPickers(5)
      $('.pickers').find('.picker').each (x, elem) =>
        color = "##{colors[x]}"
        $(elem).find('.color').val(color)
        $(elem).find('.time').val((0.25 * x).toFixed(3))
        this.updateDivColor($(elem).find('.color'), color)

      this.updateCode()

    $.getJSON("http://www.colourlovers.com/api/palettes/random?format=json&jsonCallback=?",
      { numResults: 1 },
      callback)

$ ->
  if $('.color_schemer')[0]
    window.gradient_renderer = new window.GLRenderer({el: $('canvas.gradient')})
    window.gray_renderer = new window.GLRenderer({el: $('canvas.gray')})

    gray_program = """
      precision mediump float;

      varying vec2 position;
      uniform sampler2D webcam;

      void main() {
        vec2 pos = vec2(position.x, 1. - position.y);
        vec4 color = texture2D(webcam, pos);
        float v = max(color.x, max(color.y, color.z));
        gl_FragColor = vec4(vec3(v), 1.);
      }"""

    window.gray_renderer.loadFragmentShader(gray_program)
    window.gray_renderer.link()
    window.gray_renderer.draw()

    window.transformed_renderer = new window.GLRenderer({el: $('canvas.transformed')})
    window.shaderMaker = new ShaderMaker
                            el: $('.color_schemer')
                            gradient_renderer: window.gradient_renderer
                            transformed_renderer: window.transformed_renderer

