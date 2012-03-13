class @LoginPage
  constructor: (@session, @startPage) ->

  start: ->
    $('#error').hide()

    [jid, password] = ($(id).val().trim() for id in ['#jid', '#password'])
    if jid.length == 0 || password.length == 0 || jid.indexOf('@') == -1
      $('#error').show()
      return

    @session.connect jid, password, (success) =>
      unless success
        @session.disconnect()
        $('#error').show()
        $('#password').val('').focus()
        return

      localStorage['jid'] = jid
      $('#current-user-name').text @session.bareJid()
      $('#current-user-avatar').attr 'src', @session.avatar @session.jid()
      $('#current-user-avatar').attr 'alt', @session.bareJid()
      $('#container').fadeOut 200, =>
        $('#navbar').show()
        window.location.hash = @startPage

  draw: ->
    @session.disconnect()
    jid = localStorage['jid'] || ''
    $('#navbar').hide()
    $('body').attr 'id', 'login-page'
    $('#container').hide().empty()
    $("""
      <form id="login-form">
        <div id="icon"></div>
        <h1>vines</h1>
        <fieldset id="login-form-controls">
          <input id="jid" name="jid" type="email" maxlength="1024" value="#{jid}" placeholder="Your user name"/>
          <input id="password" name="password" type="password" maxlength="1024" placeholder="Your password"/>
          <input id="start" type="submit" value="Sign in"/>
        </fieldset>
        <p id="error" style="display:none;">User name and password not found.</p>
      </form>
    """).appendTo '#container'
    $('#container').fadeIn 1000
    $('#login-form').submit => this.start(); false
    $('#jid').keydown      -> $('#error').fadeOut()
    $('#password').keydown -> $('#error').fadeOut()
    this.resize()
    this.icon()

  icon: ->
    opts =
      fill: '90-#ccc-#fff'
      stroke: '#fff'
      'stroke-width': 1.1
      opacity: 0.95
      scale: 3.0
      translation: '10,8'
      animate: false
    new Button('#icon', ICONS.chat, opts)

  resize: ->
    win  = $ window
    form = $ '#login-form'
    sizer = -> form.css 'top', win.height() / 2 - form.height() / 2
    win.resize sizer
    sizer()
