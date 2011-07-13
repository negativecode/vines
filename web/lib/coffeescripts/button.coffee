class Button
  constructor: (node, path, options) ->
    @node = $ node
    @path = path
    @options = options || {}
    this.draw()

  draw: ->
    paper = Raphael @node.get(0)

    icon = paper.path(@path).attr
      fill: @options.fill || '#000'
      stroke: @options.stroke || '#fff'
      'stroke-width': @options['stroke-width'] || 0.3
      opacity: @options.opacity || 0.6
      scale: @options.scale || 0.85
      translation: @options.translation || ''

    @node.hover(
      -> icon.animate(opacity: 1.0, 200),
      -> icon.animate(opacity: 0.6, 200))
