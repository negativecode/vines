class LoginPage
  constructor: (@router, @session) ->

  start: ->
    $('#error').hide()
    callback = (success) =>
      ($('#error').show(); return) unless success
      localStorage['jid'] = $('#jid').val()
      $('#container').fadeOut 200, =>
        $('#container').remove()
        @router.showChat()
    @session.connect $('#jid').val(), $('#password').val(), callback

  draw: ->
    jid = localStorage['jid'] || ''
    $('body').attr 'id', 'login-page'
    $("""
      <div id="container" style="display:none;">
        <form id="login-form">
          <h1>vines&gt;</h1>
          <fieldset id="login-form-controls">
            <input id="jid" name="jid" type="email" maxlength="1024" value="#{jid}" placeholder="Your user name"/>
            <input id="password" name="password" type="password" maxlength="1024" placeholder="Your password"/>
            <input id="start" type="button" value="Start Chat"/>
          </fieldset>
          <p id="error" style="display:none;">User name and password not found.</p>
        </form>
      </div>
    """).appendTo 'body'
    $('#start').click => this.start()
    $('#container').fadeIn 1500
    this.resize()

  resize: ->
    win  = $ window
    form = $ '#login-form'
    sizer = -> form.css 'top', win.height() / 2 - form.height() / 2
    win.resize sizer
    sizer()
