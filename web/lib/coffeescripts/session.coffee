class Session
  constructor: ->
    @xmpp = new Strophe.Connection '/xmpp'
    @roster = {}
    @listeners =
      card:     []
      message:  []
      presence: []
      roster:   []

  connect: (jid, password, callback) ->
    @xmpp.connect jid, password, (status) =>
      switch status
        when Strophe.Status.CONNFAIL
          callback false
        when Strophe.Status.CONNECTED
          @xmpp.addHandler ((m) => this.handleMessage(m)), null, 'message'
          @xmpp.addHandler ((p) => this.handlePresence(p)), null, 'presence'
          callback true
          this.findRoster =>
            this.notify('roster')
            this.findCards()
          @xmpp.send $pres().tree()

  onCard: (callback) ->
    @listeners['card'].push callback

  onRoster: (callback) ->
    @listeners['roster'].push callback

  onMessage: (callback) ->
    @listeners['message'].push callback

  onPresence: (callback) ->
    @listeners['presence'].push callback

  jid: -> @xmpp.jid

  bareJid: -> @xmpp.jid.split('/')[0]

  loadCard: (jid) ->
    jid = jid.split('/')[0]
    found = localStorage['vcard:' + jid]
    JSON.parse found if found

  storeCard: (card) ->
    localStorage['vcard:' + card.jid] = JSON.stringify card

  findCards: ->
    jids = (jid for jid, contacts of @roster when !this.loadCard jid)
    jids.push this.bareJid() if !this.loadCard(this.bareJid())

    success = (card) =>
      this.findCard jids.shift(), success
      if card
        this.storeCard card
        this.notify 'card', card

    this.findCard jids.shift(), success

  findCard: (jid, callback) ->
    return unless jid

    handler = (result) ->
      card  = $('vCard', result)
      photo = $('PHOTO', card)
      type  = $('TYPE', photo).text()
      bin   = $('BINVAL', photo).text()
      photo =
        if type && bin
          type: type, binval: bin.replace(/\n/g, '')
        else null
      vcard = jid: jid, photo: photo, retrieved: new Date()
      callback if card.size() > 0 then vcard else null

    iq = $iq(type: 'get', to: jid, id: @xmpp.getUniqueId())
      .c('vCard', xmlns: 'vcard-temp').up()

    @xmpp.sendIQ iq, handler, handler, 5000

  findRoster: (callback) ->
    handler = (result) =>
      contacts = $('item', result).map(->
        el = $(this)
        jid: el.attr('jid')
        name: el.attr('name')
        subscription: el.attr('subscription')
        ask: el.attr('ask')
        groups: $('group', this).map(-> $(this).text()).get()
      ).get()

      @roster[contact.jid] = contact for contact in contacts
      callback()

    iq = $iq(type: 'get', id: @xmpp.getUniqueId())
      .c('query', xmlns: 'jabber:iq:roster').up()

    @xmpp.sendIQ iq, handler, handler, 5000

  sendMessage: (jid, message) ->
    stanza = $msg(to: jid, from: @xmpp.jid, type: 'chat')
      .c('body').t(message).up()
    @xmpp.send stanza.tree()

  sendPresence: (away, status) ->
    stanza = $pres()
    if away
      stanza.c('show').t('xa').up()
      stanza.c('status').t status if status != 'Away'
    else
      stanza.c('status').t status if status != 'Available'
    @xmpp.send stanza.tree()

  handleMessage: (node) ->
    node  = $(node)
    to    = node.attr 'to'
    from  = node.attr 'from'
    type  = node.attr 'type'
    body  = node.find('body').first()
    if type == 'chat' && body.size() > 0
      this.notify 'message',
        to:   to
        from: from
        type: type
        text: body.text()
        received: new Date()
    true # keep handler alive

  handlePresence: (node) ->
    node = $(node)
    to     = node.attr 'to'
    from   = node.attr 'from'
    type   = node.attr 'type'
    show   = node.find('show').first()
    status = node.find('status').first()
    this.notify 'presence',
      to:      to
      from:    from
      status:  status.text()
      show:    show.text()
      offline: type == 'unavailable'
      away:    show.text() == 'away' || show.text() == 'xa'
      dnd:     show.text() == 'dnd'
    true # keep handler alive

  notify: (type, obj) ->
    callback(obj) for callback in (@listeners[type] || [])
