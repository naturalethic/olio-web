window <<< require 'prelude-ls'

require! \axios
require! \inflection

if console.log.apply
  <[ log info warn error ]> |> each (key) -> window[key] = -> console[key] ...&
else
  <[ log info warn error ]> |> each (key) -> window[key] = console[key]

export olio = {}

# invoke = (module, name) ->
#   return (data) ->
#     axios do
#       url: (name and "/#module/#name") or "/#module"
#       method: \put
#       headers:
#         'Content-Type': 'application/json'
#         'Accept':       'application/json'
#       data: data

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
