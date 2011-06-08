class ChatPage
  MINUS: 'M25.979,12.896,19.312,12.896,5.979,12.896,5.979,19.562,25.979,19.562z'

  PLUS:  'M25.979,12.896 19.312,12.896 19.312,6.229 12.647,6.229 12.647,' +
         '12.896 5.979,12.896 5.979,19.562 12.647,19.562 12.647,26.229 ' +
         '19.312,26.229 19.312,19.562 25.979,19.562z'

  USER:  'M20.771,12.364c0,0,0.849-3.51,0-4.699c-0.85-1.189-1.189-1.981-' +
         '3.058-2.548s-1.188-0.454-2.547-0.396c-1.359,0.057-2.492,0.792-' +
         '2.492,1.188c0,0-0.849,0.057-1.188,0.397c-0.34,0.34-0.906,1.924-' +
         '0.906,2.321s0.283,3.058,0.566,3.624l-0.337,0.113c-0.283,3.283,' +
         '1.132,3.68,1.132,3.68c0.509,3.058,1.019,1.756,1.019,2.548s-0.51' +
         ',0.51-0.51,0.51s-0.452,1.245-1.584,1.698c-1.132,0.452-7.416,2.886-' +
         '7.927,3.396c-0.511,0.511-0.453,2.888-0.453,2.888h26.947c0,0,0.059-' +
         '2.377-0.452-2.888c-0.512-0.511-6.796-2.944-7.928-3.396c-1.132-0.453-' +
         '1.584-1.698-1.584-1.698s-0.51,0.282-0.51-0.51s0.51,0.51,1.02-' +
         '2.548c0,0,1.414-0.397,1.132-3.68H20.771z'

  constructor: (@session) ->
    @session.onRoster   ( ) => this.roster()
    @session.onCard     (c) => this.card(c)
    @session.onMessage  (m) => this.message(m)
    @session.onPresence (p) => this.presence(p)
    @chats = {}
    @currentContact = null

  datef: (millis) ->
    d = new Date(millis)
    meridian = if d.getHours() >= 12 then ' pm' else ' am'
    hour = if d.getHours() > 12 then d.getHours() - 12 else d.getHours()
    hour = 12 if hour == 0
    minutes = d.getMinutes() + ''
    minutes = '0' + minutes if minutes.length == 1
    hour + ':' + minutes + meridian

  card: (card) ->
    this.eachContact card.jid, (node) =>
      $('.vcard-img', node).attr 'src', @session.avatar card.jid

  roster: ->
    roster = $('#roster').empty()
    for jid, contact of @session.roster
      node = $('<li></li>', 'data-jid': jid)
        .text(contact.name || jid)
        .append($('<span></span>', class: 'status-msg').text('Offline'))
        .append($('<span></span>', class: 'unread').hide())
        .append($('<img/>', class: 'vcard-img', src: @session.avatar(jid), alt: jid))
      node.click (event) => this.selectContact(event)
      roster.append node

  message: (message) ->
    this.queueMessage message
    me   = message.from == @session.jid()
    from = message.from.split('/')[0]

    if me || from == @currentContact
      bottom = this.atBottom()
      this.appendMessage message
      this.scroll() if bottom
    else
      chat = this.chat message.from
      chat.unread++
      this.eachContact from, (node) ->
        $('.unread', node).text(chat.unread).show()

  eachContact: (jid, callback) ->
    for node in $("#roster li[data-jid='#{jid}']").get()
      callback $(node)

  appendMessage: (message) ->
    from    = message.from.split('/')[0]
    contact = @session.roster[from]
    name    = if contact then (contact.name || from) else from
    name    = 'Me' if message.from == @session.jid()

    $('<li></li>', 'data-jid': from)
      .append($('<p></p>').text message.text)
      .append($('<img/>', src: @session.avatar(from), alt: from))
      .append($('<footer></footer>')
        .append($('<span></span>', class: 'author').text name)
        .append($('<span></span>', class: 'time').text this.datef message.received))
      .appendTo('#messages').hide().fadeIn()

  queueMessage: (message) ->
    me   = message.from == @session.jid()
    full = message[if me then 'to' else 'from']
    chat = this.chat full
    chat.jid = full
    chat.messages.push message

  chat: (jid) ->
    bare = jid.split('/')[0]
    chat = @chats[bare]
    unless chat
      chat = jid: jid, messages: [], unread: 0
      @chats[bare] = chat
    chat

  presence: (presence) ->
    from = presence.from.split('/')[0]
    return if from == @session.bareJid()
    this.eachContact from, (node) ->
      status = presence.status || 'Available'
      $('span.status-msg', node).text status

  selectContact: (event) ->
    jid = $(event.currentTarget).attr 'data-jid'
    contact = @session.roster[jid]
    return if @currentContact == jid
    @currentContact = jid

    $('#roster li').removeClass 'selected'
    $(event.currentTarget).addClass 'selected'
    $('#chat-title').text('Chat with ' + (contact.name || contact.jid))
    $('#messages').empty()

    chat = @chats[jid]
    messages = []
    if chat
      messages = chat.messages
      chat.unread = 0
      this.eachContact jid, (node) ->
        $('.unread', node).text('').hide()

    this.appendMessage msg for msg in messages
    this.scroll()

  scroll: ->
    msgs = $ '#messages'
    msgs.animate(scrollTop: msgs.prop('scrollHeight'), 400)

  atBottom: ->
    msgs = $('#messages')
    bottom = msgs.prop('scrollHeight') - msgs.height()
    msgs.scrollTop() == bottom

  send: ->
    return false unless @currentContact
    input = $('#message')
    text = input.val().trim()
    if text
      chat = @chats[@currentContact]
      jid = if chat then chat.jid else @currentContact
      this.message
        from: @session.jid()
        text: text
        to: jid
        received: new Date()
      @session.sendMessage jid, text
    input.val ''
    false

  toggleEditForm: ->
    form = $('#edit-contact-form')
    if form.is ':hidden' then form.fadeIn() else form.fadeOut()

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'chat-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha">
        <h2>Buddies</h2>
        <ul id="roster"></ul>
        <div id="controls">
          <div id="add-contact"></div>
          <div id="remove-contact"></div>
          <div id="edit-contact"></div>
        </div>
        <form id="edit-contact-form" style="display:none;">
          <input id="name" name="name" type="text" maxlength="1024" placeholder="Your name"/>
          <input id="email" name="email" type="text" maxlength="1024" placeholder="Your email"/>
        </form>
      </div>
      <div id="beta">
        <h2 id="chat-title">Select a buddy to chat</h2>
        <ul id="messages"></ul>
        <form id="message-form">
          <input id="message" name="message" type="text" maxlength="1024" placeholder="Type a message and press enter to send"/>
        </form>
      </div>
      <div id="charlie">
        <h2>Notifications</h2>
        <ul id="notifications"></ul>
        <div id="notification-controls"></div>
      </div>
    """).appendTo '#container'

    this.roster()
    this.button 'add-contact', this.PLUS
    this.button 'remove-contact', this.MINUS
    this.button 'edit-contact', this.USER

    $('#message').focus -> $('#edit-contact-form').fadeOut()
    $('#message-form').submit => this.send()
    $('#edit-contact').click  => this.toggleEditForm()

    $('#container').fadeIn 200
    this.resize()

  resize: ->
    win    = $ window
    header = $ '#navbar'
    nav    = $ '#app-nav'
    page   = $ '#container'
    a      = $ '#alpha'
    b      = $ '#beta'
    c      = $ '#charlie'
    atitle = $ '#alpha > h2'
    btitle = $ '#beta > h2'
    ctitle = $ '#charlie > h2'
    ctrls  = $ '#controls'
    msg    = $ '#message'
    msgs   = $ '#messages'
    form   = $ '#message-form'
    roster = $ '#roster'
    sizer = ->
      height = win.height() - header.height() - 1
      page.height height
      a.height height
      b.height height
      c.height height

      roster.height a.height() - ctrls.height() - atitle.height()
      msgs.height   b.height() - form.height() - btitle.height()

      b.width win.width() - a.width() - c.width()
      nav.width b.width()
      c.css 'left', a.width() + b.width()
      msg.width form.width() - 32

    win.resize sizer
    sizer()

  button: (id, path) ->
    paper = Raphael(id)
    icon = paper.path(path).attr
      fill: '#000'
      stroke: '#fff'
      'stroke-width': 0.3
      opacity: 0.6
      scale: 0.85

    node = $('#' + id)
    node.hover(
      -> icon.animate(opacity: 1.0, 200),
      -> icon.animate(opacity: 0.6, 200))
    node.get 0
