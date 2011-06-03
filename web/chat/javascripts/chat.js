var ChatPage = Class.create({
  PLUS:  'M25.979,12.896 19.312,12.896 19.312,6.229 12.647,6.229 12.647,' +
         '12.896 5.979,12.896 5.979,19.562 12.647,19.562 12.647,26.229 ' +
         '19.312,26.229 19.312,19.562 25.979,19.562z',

  MINUS: 'M25.979,12.896,19.312,12.896,5.979,12.896,5.979,19.562,25.979,19.562z',

  USER:  'M20.771,12.364c0,0,0.849-3.51,0-4.699c-0.85-1.189-1.189-1.981-' +
         '3.058-2.548s-1.188-0.454-2.547-0.396c-1.359,0.057-2.492,0.792-' +
         '2.492,1.188c0,0-0.849,0.057-1.188,0.397c-0.34,0.34-0.906,1.924-' +
         '0.906,2.321s0.283,3.058,0.566,3.624l-0.337,0.113c-0.283,3.283,' +
         '1.132,3.68,1.132,3.68c0.509,3.058,1.019,1.756,1.019,2.548s-0.51' +
         ',0.51-0.51,0.51s-0.452,1.245-1.584,1.698c-1.132,0.452-7.416,2.886-' +
         '7.927,3.396c-0.511,0.511-0.453,2.888-0.453,2.888h26.947c0,0,0.059-' +
         '2.377-0.452-2.888c-0.512-0.511-6.796-2.944-7.928-3.396c-1.132-0.453-' +
         '1.584-1.698-1.584-1.698s-0.51,0.282-0.51-0.51s0.51,0.51,1.02-' +
         '2.548c0,0,1.414-0.397,1.132-3.68H20.771z',

  initialize: function(router, session) {
    this.router = router;
    this.session = session;
    this.session.onRoster(this.roster.bind(this));
    this.session.onCard(this.card.bind(this));
    this.session.onMessage(this.message.bind(this));
    this.session.onPresence(this.presence.bind(this));
    this.chats = {};
    this.currentContact = null;
  },

  datef: function(millis) {
    var d = new Date(millis);
    var meridian = (d.getHours() >= 12) ? ' pm' : ' am';
    var hour = (d.getHours() > 12) ? d.getHours() - 12 : d.getHours();
    if (hour == 0) hour = 12;
    var minutes = d.getMinutes() + '';
    if (minutes.length == 1) minutes = '0' + minutes;
    return hour + ':' + minutes + meridian;
  },

  avatar: function(jid) {
    var image = null;
    var card = this.session.loadCard(jid);
    if (card && card.photo) {
      image = "data:" + card.photo.type + ';base64,' + card.photo.binval;
    }
    return image;
  },

  card: function(card) {
    this.eachContact(card.jid, function(node) {
      $('.vcard-img', node).attr('src', this.avatar(card.jid));
    }.bind(this));

    if (card.jid == this.session.bareJid()) {
      $('#current-user-avatar').attr('src', this.avatar(card.jid));
    }
  },

  roster: function() {
    var roster = $('#roster').empty();
    $H(this.session.roster).values().each(function(contact) {
      var node = $('<li></li>', {'data-jid': contact.jid})
        .text(contact.name || contact.jid)
        .append($('<span></span>', {'class': 'status-msg'}).text('Offline'))
        .append($('<span></span>', {'class': 'unread'}).hide())
        .append($('<img/>', {'class': 'vcard-img', src: this.avatar(contact.jid), alt: contact.jid}));
      node.click(this.selectContact.bind(this));
      roster.append(node);
    }, this);
  },

  message: function(message) {
    this.queueMessage(message);
    var me = (message.from == this.session.jid());
    var from = message.from.split('/').first()

    if (me || from == this.currentContact) {
      var bottom = this.atBottom();
      this.appendMessage(message);
      if (bottom) this.scroll(); 

    } else {
      var chat = this.chat(message.from);
      chat.unread++;
      this.eachContact(from, function(node) {
        $('.unread', node).text(chat.unread).show();
      });
    }
  },

  eachContact: function(jid, callback) {
    $('#roster li[data-jid="'+ jid +'"]').each(function() {
      callback($(this));
    });
  },

  appendMessage: function(message) {
    var from = message.from.split('/').first();
    var contact = this.session.roster[from];
    var name = contact ? (contact.name || from) : from;
    if (message.from == this.session.jid()) name = 'Me';

    $('<li></li>', {'class': from})
      .append($('<p></p>').text(message.text))
      .append($('<img/>', {src: this.avatar(from), alt: from}))
      .append($('<footer></footer>')
        .append($('<span></span>', {'class': 'author'}).text(name))
        .append($('<span></span>', {'class': 'time'}).text(this.datef(message.received))))
      .appendTo('#messages').hide().fadeIn();
  },

  queueMessage: function(message) {
    var me   = (message.from == this.session.jid());
    var full = message[me ? 'to' : 'from'];
    var chat = this.chat(full);
    chat.jid = full;
    chat.messages.push(message);
  },

  chat: function(jid) {
    var bare = jid.split('/').first();
    var chat = this.chats[bare];
    if (!chat) {
      chat = {jid: jid, messages: [], unread: 0};
      this.chats[bare] = chat;
    }
    return chat;
  },

  presence: function(presence) {
    var from = presence.from.split('/').first();
    if (from == this.session.bareJid()) return;
    this.eachContact(from, function(node) {
      var status = presence.status || 'Available';
      $('span.status-msg', node).text(status);
    });
  },

  selectContact: function(event) {
    var jid = $(event.currentTarget).attr('data-jid');
    var contact = this.session.roster[jid];
    if (this.currentContact == jid) return;
    this.currentContact = jid;

    $('#roster li').removeClass('selected');
    $(event.currentTarget).addClass('selected');
    $('#title').text('Chat with ' + (contact.name || contact.jid));
    $('#messages').empty();

    var chat = this.chats[jid];
    var messages = [];
    if (chat) {
      messages = chat.messages;
      chat.unread = 0;
      this.eachContact(jid, function(node) {
        $('.unread', node).text('').hide();
      });
    }

    messages.each(function(message) {
      this.appendMessage(message);
    }, this)
    this.scroll();
  },

  scroll: function() {
    var msgs = $('#messages');
    msgs.animate({scrollTop: msgs.prop('scrollHeight')}, 400);
  },

  atBottom: function() {
    var msgs = $('#messages');
    var bottom = msgs.prop('scrollHeight') - msgs.height();
    return msgs.scrollTop() == bottom;
  },

  send: function() {
    if (!this.currentContact) return false;
    var input = $('#message');
    var text = input.val().trim();
    if (text) {
      var chat = this.chats[this.currentContact];
      var jid = chat ? chat.jid : this.currentContact;
      this.message({
        from: this.session.jid(),
        text: text,
        to: jid,
        received: new Date()
      });
      this.session.sendMessage(jid, text);
    }
    input.val('');
    return false;
  },

  toggleEditForm: function() {
    var form = $('#edit-contact-form');
    form.is(':hidden') ? form.fadeIn() : form.fadeOut();
  },

  draw: function() {
    $('body').attr('id', 'chat-page');
    $('<div></div>', {id: 'container'}).appendTo('body');
    $('<header></header>', {id: 'app-strip'})
      .append($('<h1></h1>', {id: 'logo'}).text('vines>'))
      .append($('<div></div>', {id: 'current-user'})
        .append($('<img/>', {id: 'current-user-avatar', src: this.avatar(this.session.jid())}))
        .append($('<div></div>', {id: 'current-user-info'})
          .append($('<h1></h1>', {id: 'current-user-name'}).text(this.session.bareJid()))
          .append($('<form></form>', {id: 'current-user-presence-form'})
            .append($('<span></span>', {'class': 'select'})
              .append($('<span></span>', {'class': 'text'}).text('Available'))
              .append($('<select></select>', {id: 'current-user-presence'})
                .append($('<optgroup></optgroup>', {label: 'Available'})
                  .append($('<option></option>').text('Available'))
                  .append($('<option></option>').text('Surfing the web'))
                  .append($('<option></option>').text('Reading email'))
                )
                .append($('<optgroup></optgroup>', {label: 'Away'})
                  .append($('<option></option>', {value: 'xa'}).text('Away'))
                  .append($('<option></option>', {value: 'xa'}).text('Out to lunch'))
                  .append($('<option></option>', {value: 'xa'}).text('On the phone'))
                  .append($('<option></option>', {value: 'xa'}).text('In a meeting'))
                )
              )
            )
          )
        )
      )
      .append($('<nav></nav>', {id:'app-nav'})
        .append($('<ul></ul>', {id: 'nav-links'}))
      ).appendTo('#container');

    $('#current-user-presence').change(function(event) {
      var selected = $('option:selected', event.currentTarget);
      $('#current-user-presence-form .text').text(selected.text());
      this.session.sendPresence(selected.val() == 'xa', selected.text());
    }.bind(this));

    $('<div></div>', {id: 'alpha'})
      .append($('<h2></h2>').text('Buddies'))
      .append($('<ul></ul>', {id: 'roster'}))
      .append($('<div></div>', {id: 'controls'})
        .append($('<div></div>', {id: 'add-contact'}))
        .append($('<div></div>', {id: 'remove-contact'}))
        .append($('<div></div>', {id: 'edit-contact'}))
      ).appendTo('#container');

    this.roster();

    $('<form></form>', {id: 'edit-contact-form'})
      .append($('<input/>', {
        id: 'name',
        name: 'name',
        type: 'text',
        maxlength: '1024',
        placeholder: 'Your name'}))
      .append($('<input/>', {
        id: 'email',
        name: 'email',
        type: 'text',
        maxlength: '1024',
        placeholder: 'Your email'}))
      .appendTo('#alpha');

    $('<div></div>', {id: 'beta'})
      .append($('<div></div>', {id: 'chat-title'})
        .append($('<h2></h2>', {id: 'title'}).text('Select a buddy to chat'))
      )
      .append($('<ul></ul>', {id: 'messages'}))
      .append($('<form></form>', {id: 'message-form'})
        .append($('<input/>', {
          id: 'message',
          name: 'message',
          type: 'text',
          maxlength: '1024',
          placeholder: 'Type a message and press enter to send'}))
      ).appendTo('#container');

    $('<div></div>', {id: 'charlie'})
      .append($('<h2></h2>').text('Notifications'))
      .append($('<ul></ul>', {id: 'notifications'}))
      .append($('<div></div>', {id: 'notification-controls'})
      ).appendTo('#container');

    this.button('add-contact', this.PLUS);
    this.button('remove-contact', this.MINUS);
    this.button('edit-contact', this.USER);

    $('#message').focus(function() { $('#edit-contact-form').fadeOut() });
    $('#message-form').submit(this.send.bind(this));
    $('#edit-contact-form').hide();
    $('#edit-contact').click(this.toggleEditForm.bind(this));

    this.resize();
    $('#container').hide().fadeIn(200);
  },

  resize: function() {
    var win    = $(window);
    var a      = $('#alpha');
    var b      = $('#beta');
    var c      = $('#charlie');
    var msg    = $('#message');
    var msgs   = $('#messages');
    var form   = $('#message-form');
    var roster = $('#roster');
    var sizer = function() {
      var height = win.height() - 60;
      a.height(height);
      b.height(height);
      c.height(height);
      roster.height(height - 80);
      msgs.height(height - 80);
      b.width(win.width() - a.width() - c.width());
      c.css('left', a.width() + b.width());
      msg.width(form.width() - 32);
    };
    win.resize(sizer);
    sizer();
  },

  button: function(id, path) {
    var paper = Raphael(id);
    var icon = paper.path(path).attr({
      fill: '#000',
      stroke: '#fff',
      'stroke-width': 0.3,
      opacity: 0.6,
      scale: 0.85});
    $('#' + id).hover(
      function() { icon.animate({opacity: 1.0}, 200) },
      function() { icon.animate({opacity: 0.6}, 200) });
    return $('#' + id).get(0);
  }
});
