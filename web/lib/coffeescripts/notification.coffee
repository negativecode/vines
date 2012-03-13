class @Notification
  constructor: (@text) ->
    this.draw()

  draw: ->
    node = $('<div class="notification float" style="display:none;"></div>').appendTo 'body'
    node.text @text
    top = node.outerHeight() / 2
    left = node.outerWidth() / 2
    node.css {marginTop: "-#{top}px", marginLeft: "-#{left}px"}
    node.fadeIn 200
    fn = ->
      node.fadeOut 200, -> node.remove()
    setTimeout fn, 1500
