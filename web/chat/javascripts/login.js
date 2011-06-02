var LoginPage = Class.create({
  initialize: function(router, session) {
    this.router = router;
    this.session = session;
  },

  start: function() {
    $('#error').hide();

    var callback = function(success) {
      if (success) {
        localStorage['jid'] = $('#jid').val()
        $('#container').fadeOut(200, function() {
          $('#container').remove();
          this.router.showChat();
        }.bind(this));
      } else {
        $('#error').show();
      }
    }.bind(this);
    this.session.connect($('#jid').val(), $('#password').val(), callback);
  },

  draw: function() {
    $('body').attr('id', 'login-page');
    $('<div></div>', {id: 'container'}).hide()
      .append($('<form></form>', {id: 'login-form'})
        .append($('<h1></h1>').text('vines>'))
        .append($('<fieldset></fieldset>', {id: 'login-form-controls'})
          .append($('<input/>', {
            id: 'jid',
            name: 'jid',
            type: 'email',
            maxlength: '1024',
            value: localStorage['jid'],
            placeholder: 'Your user name'}))
          .append($('<input/>', {
            id: 'password',
            name: 'password',
            type: 'password',
            maxlength: '1024',
            placeholder: 'Your password'}))
          .append($('<input/>', {id: 'start', type: 'button', value: 'Start Chat'}))
        ).append($('<p></p>', {id: 'error'}).text('User name and password not found.').hide())
      ).appendTo('body')
      .fadeIn(1500);
    $('#start').click(this.start.bind(this));

    var win  = $(window);
    var form = $('#login-form');
    var sizer = function() {
      form.css('top', win.height() / 2 - form.height() / 2);
    };
    win.resize(sizer);
    sizer();
  }
});
