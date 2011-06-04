class Router
  constructor: ->
    session = new Session()
    @login  = new LoginPage(this, session)
    @chat   = new ChatPage(this, session)
    @pages  =
      "^#\/messages\/[a-zA-z0-9]{4}$": @chat

  showChat: -> @chat.draw()

  draw: ->
    for re, page of @pages
      if window.location.hash.match(new RegExp(re))
        page.draw()
        return
    @login.draw()

$(-> new Router().draw())
