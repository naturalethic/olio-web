require! \jade
require! \inflection
require! \regenerator
require! \browserify
require! \browserify-css
require! \watchify
require! \node-notifier
require! \stylus
require! \nib
require! \checksum

export watch = "#__dirname/web.ls"

read-view-names = Func.memoize ->
  names = glob.sync 'web/**/*.+(jade|ls|styl)'
  |> map -> it.replace(/^web\//, '').replace(/\.(jade|ls|styl)$/, '').replace(/\//g, '-')
  |> unique
  |> map ->
    parts = it.split('-')
    if parts.length > 1 and parts[parts.length - 2] in [(last parts), (inflection.singularize last parts)]
      return (parts.slice(0, parts.length - 2) ++ [ last parts ]).join '-'
    it
  # XXX: Move html to the front for initialization type work
  if \html in names
    names.splice (names.index-of \html), 1
    names = <[ html ]> ++ names
  names

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
  re-include = /^\/\/\s+INCLUDE\s+(.*)$/gm
  re-url     = /url\("([^":]+)"\)/gm
  includes = [
    "#__dirname/../node_modules/semantic-ui-css/semantic.css"
  ]
  source = []
  styles = []
  for it in read-view-names!
    return if !path = view-path-for-name it, 'styl'
    styl = fs.read-file-sync(path).to-string!
    while m = re-include.exec styl
      if fs.exists-sync m.1
        includes.push m.1
    styles.push styl
  for ipath in includes
    incl = fs.read-file-sync ipath .to-string!
    while n = re-url.exec incl
      path = n.1.split(/[\#\?]/).0
      copy-if-changed "#{fs.path.dirname(ipath)}/#path", "public/#{fs.path.dirname path}/#{fs.path.basename path}"
    source.push incl
  (promisify-all stylus(styles.join('\n')).use(nib()).import("nib")).render-async!
  .then ->
    info 'Writing    -> public/index.css'
    source.push it
    fs.write-file-sync \public/index.css, source.join('\n')

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
  fs.write-file-sync \tmp/template.js, livescript.compile(script.join('\n'), { -header })
  info 'Writing    -> public/index.html'
  fs.write-file-sync \public/index.html, components.html.html

stitch-scripts = ->
  script = ["""
    window <<< require 'olio-web'
    olio.template = require './template'
  """]
  if fs.exists-sync 'web/html.ls'
    script.push (fs.read-file-sync 'web/html.ls').to-string!
  for key, val of require-dir \api
    for k, v of val
      script.push "olio.api._add '#key', '#k'"
  script = [
    livescript.compile script.join('\n'), { -header }
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

copy = (source, target) ->
  info "Copy       -> #target"
  exec "mkdir -p #{fs.path.dirname target}"
  exec "cp #source #target"

copy-if-changed = (source, target) ->
  return copy source, target if !fs.exists-sync target
  checksum.file source, (_, s1) ->
    checksum.file target, (_, s2) ->
      copy source, target if s1 != s2

copy-static = ->
  glob.sync 'web/**/*.!(ls|jade|styl)'
  |> each ->
    copy-if-changed it, "public/#{/web\/(.*)/.exec(it).1}"

setup-bundler = ->
  bundler := watchify browserify <[ ./tmp/index.js ]>,
    detect-globals: false
    cache: {}
    package-cache: {}
  bundler.on \update, ->
    bundle!

done = ->
  node-notifier.notify title: (inflection.capitalize olio.config.name), message: "Site Rebuilt: #{(Date.now! - time) / 1000}s"
  info "--- Done in #{(Date.now! - time) / 1000} seconds ---"
  process.exit 0 if olio.option.exit

bundle = ->
  info 'Browserify -> public/index.js'
  bundler.bundle!
  .pipe fs.create-write-stream 'public/index.js'
  .on 'finish', done

build = (what) ->
  try
    time := Date.now!
    switch what
    | \all =>
      copy-static!
      stitch-templates!
      stitch-styles!
      stitch-scripts!
    | \jade =>
      stitch-templates!
      stitch-scripts!
    | \styl =>
      stitch-styles!
      done!
    | \ls =>
      stitch-scripts!
    | otherwise =>
      copy-static!
  catch e
    info e

export web = ->*
  exec "mkdir -p tmp"
  exec "mkdir -p public"
  exec "ln -fs ../node_modules/olio-web/node_modules tmp"
  setup-bundler!
  watcher.watch <[ olio.ls host.ls web ]>, persistent: true, ignore-initial: true .on 'all', (event, path) ->
    info "Change detected in '#path'..."
    build (/\.(\w+)$/.exec path).1
  build \all
  bundle!

