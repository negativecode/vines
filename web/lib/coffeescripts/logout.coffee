class @LogoutPage
  constructor: (@session) ->
  draw: ->
    window.location.hash = ''
    window.location.reload()
