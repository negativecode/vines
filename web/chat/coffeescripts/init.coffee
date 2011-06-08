$ ->
  session = new Session()
  nav = new NavBar(session)
  nav.draw()
  pages =
    '/messages': new ChatPage(session)
    'default':   new LoginPage(session, '/messages/')
  new Router(pages).draw()
