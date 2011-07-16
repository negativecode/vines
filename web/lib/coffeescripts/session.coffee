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
          @xmpp.addHandler ((el) => this.handleIq(el)), null, 'iq'
          @xmpp.addHandler ((el) => this.handleMessage(el)), null, 'message'
          @xmpp.addHandler ((el) => this.handlePresence(el)), null, 'presence'
          callback true
          this.findRoster =>
            this.notify('roster')
            @xmpp.send $pres().tree()
            this.findCards()

  disconnect: -> @xmpp.disconnect()

  onCard: (callback) ->
    @listeners['card'].push callback

  onRoster: (callback) ->
    @listeners['roster'].push callback

  onMessage: (callback) ->
    @listeners['message'].push callback

  onPresence: (callback) ->
    @listeners['presence'].push callback

  connected: ->
    @xmpp.jid && @xmpp.jid.length > 0

  jid: -> @xmpp.jid

  bareJid: -> @xmpp.jid.split('/')[0]

  uniqueId: -> @xmpp.getUniqueId()

  avatar: (jid) ->
    card = this.loadCard(jid)
    if card && card.photo
      "data:#{card.photo.type};base64,#{card.photo.binval}"
    else
      '/lib/images/default-user.png'

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

    this.sendIQ iq, handler

  parseRoster: (node) ->
    $('item', node).map(-> new Contact this ).get()

  findRoster: (callback) ->
    handler = (result) =>
      contacts = this.parseRoster(result)
      @roster[contact.jid] = contact for contact in contacts
      callback()

    iq = $iq(type: 'get', id: @xmpp.getUniqueId())
      .c('query', xmlns: 'jabber:iq:roster').up()

    this.sendIQ iq, handler

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

  sendIQ: (node, callback) ->
    @xmpp.sendIQ node, callback, callback, 5000

  updateContact: (contact, add) ->
    iq = $iq(type: 'set', id: @xmpp.getUniqueId())
      .c('query', xmlns: 'jabber:iq:roster')
      .c('item', jid: contact.jid, name: contact.name)
    iq.c('group', group).up() for group in contact.groups
    @xmpp.send iq.up().tree()
    @xmpp.send $pres(type: 'subscribe', to: contact.jid).tree() if add

  removeContact: (jid) ->
    iq = $iq(type: 'set', id: @xmpp.getUniqueId())
      .c('query', xmlns: 'jabber:iq:roster')
      .c('item', jid: jid, subscription: 'remove')
      .up().up()
    @xmpp.send iq.tree()

  sendSubscribe: (jid) ->
    @xmpp.send $pres(
      type: 'subscribe'
      to: jid
      id: @xmpp.getUniqueId()
    ).tree()

  sendSubscribed: (jid) ->
    @xmpp.send $pres(
      type: 'subscribed'
      to: jid
      id: @xmpp.getUniqueId()
    ).tree()

  sendUnsubscribed: (jid) ->
    @xmpp.send $pres(
      type: 'unsubscribed'
      to: jid
      id: @xmpp.getUniqueId()
    ).tree()

  handleIq: (node) ->
    node = $(node)
    type = node.attr 'type'
    ns   = node.find('query').attr 'xmlns'
    if type == 'set' && ns == 'jabber:iq:roster'
      contacts = this.parseRoster(node)
      for contact in contacts
        if contact.subscription == 'remove'
          delete @roster[contact.jid]
        else
          old = @roster[contact.jid]
          contact.presence = old.presence if old
          @roster[contact.jid] = contact
      this.notify('roster')
    true # keep handler alive

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
    node   = $(node)
    to     = node.attr 'to'
    from   = node.attr 'from'
    type   = node.attr 'type'
    show   = node.find('show').first()
    status = node.find('status').first()
    presence =
      to:      to
      from:    from
      status:  status.text()
      show:    show.text()
      type:    type
      offline: type == 'unavailable' || type == 'error'
      away:    show.text() == 'away' || show.text() == 'xa'
      dnd:     show.text() == 'dnd'
    contact = @roster[from.split('/')[0]]
    contact.update presence if contact
    this.notify 'presence', presence
    true # keep handler alive

  notify: (type, obj) ->
    callback(obj) for callback in (@listeners[type] || [])
