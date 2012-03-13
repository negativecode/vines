class @Session
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
        when Strophe.Status.AUTHFAIL, Strophe.Status.CONNFAIL
          callback false
        when Strophe.Status.CONNECTED
          @xmpp.addHandler ((el) => this.handleIq(el)), null, 'iq'
          @xmpp.addHandler ((el) => this.handleMessage(el)), null, 'message'
          @xmpp.addHandler ((el) => this.handlePresence(el)), null, 'presence'
          callback true
          this.findRoster =>
            this.notify('roster')
            @xmpp.send this.xml '<presence/>'
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
    node = this.xml """
      <iq id="#{this.uniqueId()}" to="#{jid}" type="get">
        <vCard xmlns="vcard-temp"/>
      </iq>
    """
    this.sendIQ node, (result) ->
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

  parseRoster: (node) ->
    $('item', node).map(-> new Contact this ).get()

  findRoster: (callback) ->
    node = this.xml """
      <iq id='#{this.uniqueId()}' type="get">
        <query xmlns="jabber:iq:roster"/>
      </iq>
    """
    this.sendIQ node, (result) =>
      contacts = this.parseRoster(result)
      @roster[contact.jid] = contact for contact in contacts
      callback()

  sendMessage: (jid, message) ->
    node = this.xml """
      <message id="#{this.uniqueId()}" to="#{jid}" type="chat">
        <body></body>
      </message>
    """
    $('body', node).text message
    @xmpp.send node

  sendPresence: (away, status) ->
    node = $ this.xml '<presence/>'
    if away
      node.append $(this.xml '<show>xa</show>')
      node.append $(this.xml '<status/>').text status if status != 'Away'
    else
      node.append $(this.xml '<status/>').text status if status != 'Available'
    @xmpp.send node

  sendIQ: (node, callback) ->
    @xmpp.sendIQ node, callback, callback, 5000

  updateContact: (contact, add) ->
    node = this.xml """
      <iq id="#{this.uniqueId()}" type="set">
        <query xmlns="jabber:iq:roster">
          <item name="" jid="#{contact.jid}"/>
        </query>
      </iq>
    """
    $('item', node).attr 'name', contact.name
    for group in contact.groups
      $('item', node).append $(this.xml '<group></group>').text group
    @xmpp.send node
    this.sendSubscribe(contact.jid) if add

  removeContact: (jid) ->
    node = this.xml """
      <iq id="#{this.uniqueId()}" type="set">
        <query xmlns="jabber:iq:roster">
          <item jid="#{jid}" subscription="remove"/>
        </query>
      </iq>
    """
    @xmpp.send node

  sendSubscribe: (jid) ->
    @xmpp.send this.presence jid, 'subscribe'

  sendSubscribed: (jid) ->
    @xmpp.send this.presence jid, 'subscribed'

  sendUnsubscribed: (jid) ->
    @xmpp.send this.presence jid, 'unsubscribed'

  presence: (to, type) ->
    this.xml """
      <presence
        id="#{this.uniqueId()}"
        to="#{to}"
        type="#{type}"/>
    """

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
    node   = $(node)
    to     = node.attr 'to'
    from   = node.attr 'from'
    type   = node.attr 'type'
    thread = node.find('thread').first()
    body   = node.find('body').first()
    this.notify 'message',
      to:   to
      from: from
      type: type
      thread: thread.text()
      text: body.text()
      received: new Date()
      node: node
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
      node:    node
    contact = @roster[from.split('/')[0]]
    contact.update presence if contact
    this.notify 'presence', presence
    true # keep handler alive

  notify: (type, obj) ->
    callback(obj) for callback in (@listeners[type] || [])

  xml: (xml) -> $.parseXML(xml).documentElement
