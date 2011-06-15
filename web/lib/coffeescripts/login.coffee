class LoginPage
  constructor: (@session, @startPage) ->

  start: ->
    $('#error').hide()
    callback = (success) =>
      unless success
        @session.disconnect()
        $('#error').show()
        $('#password').val('').focus()
        return

      localStorage['jid'] = $('#jid').val()
      $('#current-user-name').text @session.bareJid()
      $('#current-user-avatar').attr 'src', @session.avatar(@session.jid())
      $('#current-user-avatar').attr 'alt', @session.bareJid()
      $('#container').fadeOut 200, =>
        $('#navbar').show()
        window.location.hash = @startPage

    @session.connect $('#jid').val(), $('#password').val(), callback
    false

  draw: ->
    @session.disconnect()
    jid = localStorage['jid'] || ''
    $('#navbar').hide()
    $('body').attr 'id', 'login-page'
    $('#container').hide().empty()
    $("""
      <form id="login-form">
        <h1>vines&gt;</h1>
        <fieldset id="login-form-controls">
          <input id="jid" name="jid" type="email" maxlength="1024" value="#{jid}" placeholder="Your user name"/>
          <input id="password" name="password" type="password" maxlength="1024" placeholder="Your password"/>
          <input id="start" type="submit" value="Sign in"/>
        </fieldset>
        <p id="error" style="display:none;">User name and password not found.</p>
      </form>
    """).appendTo '#container'
    $('#login-form').submit => this.start()
    $('#container').fadeIn 1000
    $('#jid').keydown      -> $('#error').fadeOut()
    $('#password').keydown -> $('#error').fadeOut()
    this.resize()

  resize: ->
    win  = $ window
    form = $ '#login-form'
    sizer = -> form.css 'top', win.height() / 2 - form.height() / 2
    win.resize sizer
    sizer()
