class @Router
  constructor: (@pages) ->
    @routes = this.build()
    $(window).bind 'hashchange', => this.draw()

  build: ->
    routes = []
    for pattern, page of @pages
      routes.push route = args: [], page: page, re: null
      if pattern == 'default'
        route.re = pattern
        continue

      fragments = (f for f in pattern.split '/' when f.length > 0)
      map = (fragment) ->
        if fragment[0] == ':'
          route.args.push fragment.replace ':', ''
          '(/[^/]+)?'
        else '/' + fragment
      route.re = new RegExp '#' + (map f for f in fragments).join ''
    routes

  draw: ->
    [route, args] = this.match()
    route ||= this.defaultRoute()
    return unless route
    [opts, ix] = [{}, 0]
    opts[name] = args[ix++] for name in route.args
    route.page.draw(opts)

  match: ->
    for route in @routes
      if match = window.location.hash.match route.re
        args = (arg.replace '/', '' for arg in match[1..-1])
        return [route, args]
    []

  defaultRoute: ->
    for route in @routes
      return route if route.re == 'default'
