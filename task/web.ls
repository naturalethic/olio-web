require! \jade
require! \inflection
require! \regenerator
require! \browserify
require! \watchify
require! \node-notifier
require! \stylus
require! \nib

_names = null
read-view-names = ->
  return _names if _names
  _names := glob.sync 'web/**/*.+(jade|ls|styl)'
  |> map -> it.replace(/^web\//, '').replace(/\.(jade|ls|styl)$/, '').replace(/\//g, '-')
  |> unique
  |> map ->
    parts = it.split('-')
    if parts.length > 1 and parts[parts.length - 2] in [(last parts), (inflection.singularize last parts)]
      return (parts.slice(0, parts.length - 2) ++ [ last parts ]).join '-'
    it
  # XXX: Always execute html first, if it exists, for setting up initializations and globals
  if \html in _names
    _names.splice _names.index-of \html
    _names := <[ html ]> ++ _names
  _names

view-path-for-name = (name, ext) ->
  parts = name.split('-')
  fname = take (parts.length - 1), parts
  lname = last parts
  sname = inflection.singularize lname
  paths =
    "web/#{parts.join('/')}.#ext"
    "web/#{fname.join('/')}/#sname/#lname.#ext"
    "web/#{fname.join('/')}/#lname/#lname.#ext"
  first (paths |> filter -> fs.exists-sync it)

stitch-styles = ->
  source = []
  read-view-names! |> each ->
    return if !path = view-path-for-name it, 'styl'
    source.push(fs.read-file-sync(path).to-string!)
  stylus(source.join '\n').use(nib()).import("nib").render (_, it) ->
    info 'Writing    -> public/index.css'
    fs.write-file-sync \public/index.css, it

stitch-templates = ->
  script = ["""
  """]
  components = {}
  for name in read-view-names!
    continue if not path = view-path-for-name name, \jade
    components[name] =
      path: path
      html: jade.render-file path, { +pretty }
    continue if name is \html
    script.push "export #name = '#{components[name].html.replace(/'/g, "\\'")}'"
  info 'Writing    -> tmp/template.js'
  fs.write-file-sync \tmp/template.js, livescript.compile(script.join('\n'))
  info 'Writing    -> public/index.html'
  fs.write-file-sync \public/index.html, components.html.html


stitch-scripts = ->
  script = ["""
    window <<< require 'olio-web'
    olio.template = require './template'
  """]
  script ++= [
    ((fs.exists-sync 'web/html.ls') and (fs.read-file-sync 'web/html.ls').to-string!) or ''
    # "require './index.css'"
  ]
  for key, val of require-dir \api
    for k, v of val
      script.push "olio.api._add '#key', '#k'"
  script = script.join '\n'
  script = [
    livescript.compile script, { header: false, bare: true }
  ]
  # validate = require '../../olio-api/validate'
  # f = validate.to-string!replace(/^function\*/, 'function').replace(/yield\sthis._validator/, 'this._validator')
  # script.push "window.validate = #f;"
  # for name, func of validate
  #   script.push "validate.#name = #{func.to-string!};\n"
  info 'Writing    -> tmp/index.js'
  fs.write-file-sync \tmp/index.js, regenerator.compile(script.join('\n'), include-runtime: true).code


time = null
bundler = null

setup-bundler = ->
  glob.sync 'web/**/*.!(ls|jade|styl)'
  |> each ->
    path = "public/#{/web\/(.*)/.exec(it).1}"
    exec "mkdir -p #{fs.path.dirname path}"
    exec "cp #it #path"
  bundler := watchify browserify <[ ./tmp/index.js ]>,
    detect-globals: false
    cache: {}
    package-cache: {}
  # bundler.transform browserify-css,
  #   auto-inject-options: { verbose: false }
  #   process-relative-url: (url) ->
  #     path = /([^\#\?]*)/.exec(url).1
  #     base = fs.path.basename path
  #     exec "cp #path public/#base"
  #     "#base"

bundle = ->
  info 'Browserify -> public/index.js'
  bundler.bundle!
  .pipe fs.create-write-stream 'public/index.js'
  .on 'finish', ->
    info "--- Done in #{(Date.now! - time) / 1000} seconds ---"
    node-notifier.notify title: (inflection.capitalize olio.config.name), message: "Site Rebuilt: #{(Date.now! - time) / 1000}s"
    process.exit 0 if olio.option.exit

build = (what) ->*
  try
    time := Date.now!
    exec "mkdir -p tmp"
    exec "mkdir -p public"
    # switch what
    # | otherwise =>
      # stitch-templates!
    stitch-styles!
    stitch-templates!
    stitch-scripts!
    bundle!
  catch e
    info e

export web = ->*
  setup-bundler!
  watcher.watch <[ olio.ls host.ls web ]>, persistent: true, ignore-initial: true .on 'all', (event, path) ->
    info "Change detected in '#path'..."
    if /styl$/.test path
      co build \styles
    else
      co build
  co build
