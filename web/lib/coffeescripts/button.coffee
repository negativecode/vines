class @Button
  constructor: (node, path, options) ->
    @node = $ node
    @path = path
    @options = options || {}
    @options.animate = true unless @options.animate?
    this.draw()

  draw: ->
    paper = Raphael @node.get(0)

    transform = "s#{@options.scale || 0.85}"
    transform += ",t#{@options.translation}" if @options.translation

    icon = paper.path(@path).attr
      fill: @options.fill || '#000'
      stroke: @options.stroke || '#fff'
      'stroke-width': @options['stroke-width'] || 0.3
      opacity: @options.opacity || 0.6
      transform: transform

    if @options.animate
      @node.hover(
        -> icon.animate(opacity: 1.0, 200),
        -> icon.animate(opacity: 0.6, 200))
