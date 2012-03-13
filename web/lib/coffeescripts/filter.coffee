class @Filter
  constructor: (options) ->
    @list  = options.list
    @icon  = options.icon
    @form  = options.form
    @attrs = options.attrs
    @open  = options.open
    @close = options.close
    this.draw()

  draw: ->
    $(@icon).addClass 'filter-button'
    form = $('<form class="filter-form" style="display:none;"></form>').appendTo @form
    text = $('<input class="filter-text" type="search" placeholder="Filter" results="5"/>').appendTo form

    if @icon
      new Button @icon, ICONS.search,
        scale: 0.5
        translation: '-16,-16'

    form.submit -> false
    text.keyup  => this.filter(text)
    text.change => this.filter(text)
    text.click  => this.filter(text)
    $(@icon).click =>
      if form.is ':hidden'
        this.filter(text)
        form.show()
        this.open() if this.open
      else
        form.hide()
        form[0].reset()
        this.filter(text)
        this.close() if this.close

  filter: (input) ->
    text = input.val().toLowerCase()
    if text == ''
      $('li', @list).show()
      return

    test = (node, attr) ->
      val = (node.attr(attr) || '').toLowerCase()
      val.indexOf(text) != -1

    $('> li', @list).each (ix, node) =>
      node = $ node
      matches = (true for attr in @attrs when test node, attr)
      if matches.length > 0 then node.show() else node.hide()
