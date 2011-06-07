$ ->
  session = new Session()
  pages =
    '/messages': new ChatPage(session)
    'default':   new LoginPage(session)
  new Router(pages).draw()