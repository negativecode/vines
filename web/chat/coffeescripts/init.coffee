$ ->
  session = new Session()
  nav = new NavBar(session)
  nav.draw()
  buttons =
    Messages: ICONS.chat
    Logout:   ICONS.power
  nav.addButton(label, icon) for label, icon of buttons

  pages =
    '/messages': new ChatPage(session)
    '/logout':   new LogoutPage(session)
    'default':   new LoginPage(session, '/messages/')
  new Router(pages).draw()
  nav.select $('#nav-link-messages').parent()
