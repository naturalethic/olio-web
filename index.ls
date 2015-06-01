window <<< require 'prelude-ls'
window.$ = window.j-query = require 'semantic-ui-css/node_modules/jquery/dist/jquery'
require 'semantic-ui-css/semantic'

require! \axios
require! \inflection
require! 'reactive'

if console.log.apply
  <[ log info warn error ]> |> each (key) -> window[key] = -> console[key] ...&
else
  <[ log info warn error ]> |> each (key) -> window[key] = console[key]

export olio = {}

olio.api =
  _add: (module, name) ->
    name ?= module
    olio.api[module] ?= {}
    func = (data) ->
      axios do
        url: (name and "/#module/#name") or "/#module"
        method: \put
        headers:
          'Content-Type': 'application/json'
          'Accept':       'application/json'
        data: data
    if name in [ module, inflection.pluralize(module) ]
      olio.api[name] = func
    else
      olio.api[module][name] = func

olio.state = {}

olio.go = (route, state) ->
  history.push-state state, '', route

window.onpopstate = ->
  info \STATE, it

bindings =
  route: (el, val) ->
    $ el .hide! if val != olio.state.route

$ ->
  olio.state.route = location.pathname
  history.replace-state null, '', location.pathname
  for name, template of olio.template
    $ ".#name:not(.olio-initialized)" |> each (el) ->
      attrs = ''
      el.attributes |> each ->
        if it.name is \class
          it.value += ' olio-initialized'
        it.value = it.value.replace /"/g, "'"
        attrs += " #{it.name}=\"#{it.value}\""
      view = reactive "<div#attrs>#template</div>", olio.state, bindings: bindings
      $ el .replace-with view.el
