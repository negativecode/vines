var Session = Class.create({
  initialize: function() {
    this.xmpp = new Strophe.Connection('/xmpp');
    this.listeners = {'cards': [], 'message': [], 'presence': [], 'roster': []};
    this.roster = {};
  },

  connect: function(jid, password, callback) {
    this.xmpp.connect(jid, password, function(status) {
      switch (status) {
        case Strophe.Status.CONNFAIL:
          callback(false);
          break;
        case Strophe.Status.CONNECTED:
          this.xmpp.addHandler(this.handleMessage.bind(this), null, 'message');
          this.xmpp.addHandler(this.handlePresence.bind(this), null, 'presence');
          callback(true);
          this.findRoster(function() {
            this.notify('roster')
            this.findCards()
          }.bind(this));
          this.xmpp.send($pres().tree());
          break;
      }
    }.bind(this));
  },

  onCards: function(callback) {
    this.listeners['cards'].push(callback);
  },

  onRoster: function(callback) {
    this.listeners['roster'].push(callback);
  },

  onMessage: function(callback) {
    this.listeners['message'].push(callback);
  },

  onPresence: function(callback) {
    this.listeners['presence'].push(callback);
  },

  jid: function() {
    return this.xmpp.jid;
  },

  bareJid: function() {
    return this.xmpp.jid.split('/').first();
  },

  loadCard: function(jid) {
    jid = jid.split('/').first()
    var found = localStorage['vcard:' + jid];
    return found ? JSON.parse(found) : null;
  },

  storeCard: function(card) {
    localStorage['vcard:' + card.jid] = JSON.stringify(card);
  },

  findCards: function() {
    var me = this.jid().split('/').first();
    var jids = [$H(this.roster).keys(), me].flatten()
      .filter(function(jid) { return !this.loadCard(jid) }, this);

    var notified = false;
    var success = function(card) {
      if (card) this.storeCard(card);
      this.findCard(jids.shift(), success);
      if (!notified) {
        notified = true;
        this.notify('cards');
      }
    }.bind(this);
    this.findCard(jids.shift(), success);
  },

  findCard: function(jid, callback) {
    if (!jid) return;

    var handler = function(result) {
      var card  = $('vCard', result);
      var photo = $('PHOTO', card);
      var type  = $('TYPE', photo).text();
      var bin   = $('BINVAL', photo).text();
      var photo = (type && bin)
        ? {type: type, binval: bin.gsub("\n", '')}
        : null;
      var vcard = {jid: jid, photo: photo, retrieved: new Date()};
      callback(card.size() > 0 ? vcard : null);
    }

    var iq = $iq({type: 'get', to: jid, id: this.xmpp.getUniqueId()})
      .c('vCard', {xmlns: 'vcard-temp'}).up();

    this.xmpp.sendIQ(iq, handler, handler, 5000);
  },

  findRoster: function(callback) {
    var handler = function(result) {
      var contacts = $('item', result).map(function() {
        var el = $(this);
        return {
          jid: el.attr('jid'),
          name: el.attr('name'),
          subscription: el.attr('subscription'),
          ask: el.attr('ask'),
          groups: $('group', this).map(
            function() { return $(this).text() }
          ).get()
        };
      }).get();

      contacts.each(function(contact) {
        this.roster[contact.jid] = contact;
      }, this);

      callback();
    }.bind(this);

    var iq = $iq({type: 'get', id: this.xmpp.getUniqueId()})
      .c('query', {xmlns: 'jabber:iq:roster'}).up();

    this.xmpp.sendIQ(iq, handler, handler, 5000);
  },

  sendMessage: function(jid, message) {
    var stanza = $msg({to: jid, from: this.xmpp.jid, type: 'chat'})
      .c('body').t(message).up();
    this.xmpp.send(stanza.tree());
  },

  sendPresence: function(away, status) {
    var stanza = $pres()
    if (away) {
      stanza.c('show').t('xa').up()
      if (status != 'Away') {
        stanza.c('status').t(status)
      }
    } else {
      if (status != 'Available') {
        stanza.c('status').t(status)
      }
    }
    this.xmpp.send(stanza.tree());
  },

  handleMessage: function(node) {
    node = $(node);

    var to    = node.attr('to');
    var from  = node.attr('from');
    var type  = node.attr('type');
    var body  = node.find('body').first();

    if (type == 'chat' && body.size() > 0) {
      this.notify('message', {
        to:   to,
        from: from,
        type: type,
        text: body.text(),
        received: new Date()
      });
    }
    return true; // keep handler alive
  },

  handlePresence: function(node) {
    node = $(node);

    var to     = node.attr('to');
    var from   = node.attr('from');
    var type   = node.attr('type');
    var show   = node.find('show').first();
    var status = node.find('status').first();

    this.notify('presence', {
      to:      to,
      from:    from,
      status:  status.text(),
      show:    show.text(),
      offline: type == 'unavailable',
      away:    show.text() == 'away' || show.text() == 'xa',
      dnd:     show.text() == 'dnd',
    });
    return true; // keep handler alive
  },

  notify: function(type, obj) {
    (this.listeners[type] || [])
      .each(function(callback) { callback(obj) });
  }
});
