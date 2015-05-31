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

$ ->
  for name, template of olio.template
    $ ".#name" |> each ->
      $ it .append template