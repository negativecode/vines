class @Contact
  constructor: (node) ->
    node  = $(node)
    @jid  = node.attr 'jid'
    @name = node.attr 'name'
    @ask  = node.attr 'ask'
    @subscription = node.attr 'subscription'
    @groups = $('group', node).map(-> $(this).text()).get()
    @presence = []

  online: ->
    @presence.length > 0

  offline: ->
    @presence.length == 0

  available: ->
    this.online() && (p for p in @presence when !p.away).length > 0

  away: -> !this.available()

  status: ->
    available = (p.status for p in @presence when p.status && !p.away)[0] || 'Available'
    away = (p.status for p in @presence when p.status && p.away)[0] || 'Away'
    if this.offline()   then 'Offline'
    else if this.away() then away
    else available

  update: (presence) ->
    @presence = (p for p in @presence when p.from != presence.from)
    @presence.push presence unless presence.type
    @presence = [] if presence.type == 'unsubscribed'
