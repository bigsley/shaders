Editor = Backbone.View.extend
  initialize: (args) ->
    @el = args['el']
    self = this

  refresh: ->
    src = window.codeMirror.getValue()
    window.renderer.loadFragmentShader(src)
    window.renderer.link()
    window.renderer.draw()

$ ->
  if $('#editor')[0]
    window.renderer = new window.GLRenderer({el: $('#canvas')})
    element = $('#editor')
    window.editor = new Editor({el: element, renderer: window.renderer})
    window.codeMirror = CodeMirror(element[0], {
      mode: "text/x-glsl"
      lineNumbers: true
      onChange: window.editor.refresh
    })


