class @NavBar
  constructor: (@session) ->
    @session.onCard (card) =>
      if card.jid == @session.bareJid()
        $('#current-user-avatar').attr 'src', @session.avatar card.jid

  draw: ->
    $("""
      <header id="navbar" class="x-fill">
        <h1 id="logo">vines&gt;</h1>
        <div id="current-user">
          <img id="current-user-avatar" alt="#{@session.bareJid()}" src="#{@session.avatar(@session.jid())}"/>
          <div id="current-user-info">
            <h1 id="current-user-name">#{@session.bareJid()}</h1>
            <form id="current-user-presence-form">
              <span class="select">
                <span class="text">Available</span>
                <select id="current-user-presence">
                  <optgroup label="Available">
                    <option>Available</option>
                    <option>Surfing the web</option>
                    <option>Reading email</option>
                  </optgroup>
                  <optgroup label="Away">
                    <option value="xa">Away</option>
                    <option value="xa">Out to lunch</option>
                    <option value="xa">On the phone</option>
                    <option value="xa">In a meeting</option>
                  </optgroup>
                </select>
              </span>
            </form>
          </div>
        </div>
        <nav id="app-nav" class="x-fill">
          <ul id="nav-links"></ul>
        </nav>
      </header>
    """).appendTo 'body'
    $('<div id="container" class="x-fill y-fill"></div>').appendTo 'body'

    $('#current-user-presence').change (event) =>
      selected = $ 'option:selected', event.currentTarget
      $('#current-user-presence-form .text').text selected.text()
      @session.sendPresence selected.val() == 'xa', selected.text()

  addButton: (label, icon) ->
    id = "nav-link-#{label.toLowerCase()}"
    node = $("""
      <li>
        <a id="#{id}" href="#/#{label.toLowerCase()}">
          <span>#{label}</span>
        </a>
      </li>
    """).appendTo '#nav-links'
    this.button(id, icon)
    node.click (event) => this.select(event.currentTarget)

  select: (button) ->
    button = $(button)
    $('#nav-links li').removeClass('selected')
    $('#nav-links li a').removeClass('selected')
    button.addClass('selected')
    $('a', button).addClass('selected')
    dark = $('#nav-links svg path')
    dark.attr 'opacity', '0.6'
    dark.css  'opacity', '0.6'
    light = $('svg path', button)
    light.attr 'opacity', '1.0'
    light.css  'opacity', '1.0'

  button: (id, path) ->
    paper = Raphael(id)
    icon = paper.path(path).attr
      fill: '#fff'
      stroke: '#000'
      'stroke-width': 0.3
      opacity: 0.6

    node = $('#' + id)
    node.hover(
      -> icon.animate(opacity: 1.0, 200),
      -> icon.animate(opacity: 0.6, 200) unless node.hasClass('selected'))
    node.get 0
