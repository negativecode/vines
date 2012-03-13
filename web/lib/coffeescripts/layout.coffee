class @Layout
  constructor: (@fn) ->
    this.resize()
    this.listen()
    setTimeout (=> this.resize()), 250

  resize: ->
    this.fill '.x-fill', 'outerWidth', 'width'
    this.fill '.y-fill', 'outerHeight', 'height'
    this.fn()

  fill: (selector, get, set) ->
    $(selector).each (ix, node) =>
      node = $(node)
      getter = node[get]
      parent = getter.call node.parent(), true
      fixed = this.fixed node, selector, (n) -> getter.call(n, true)
      node[set].call node, parent - fixed

  fixed: (node, selector, fn) ->
    node.siblings().not(selector).not('.float').filter(':visible')
      .map(-> fn $ this).get()
      .reduce ((sum, num) -> sum + num), 0

  listen: ->
    id = null
    $(window).resize =>
      clearTimeout id
      id = setTimeout (=> this.resize()), 10
      this.resize()
