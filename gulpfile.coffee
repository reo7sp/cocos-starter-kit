gulp = require 'gulp'
$ = require('gulp-load-plugins')()

process = require 'process'
fs = require 'fs'
childProcess = require 'child_process'
exec = childProcess.exec
execSync = childProcess.execSync

_ = require 'lodash'
glob = require 'glob'
del = require 'del'
runSequence = require 'run-sequence'
yargs = require 'yargs'
Q = require 'q'
ejs = require 'ejs'

browserify = require 'browserify'
browserifyInc = require 'browserify-incremental'
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'

express = require 'express'


# --- utils --- #
plumberOptions =
  errorHandler: (err) ->
    $.util.beep()
    $.util.log(
      $.util.colors.red('Unhandled error:\n'),
      err.toString()
    )
    @emit("end")


get_platforms = ->
  try
    for line in execSync('cocos run --list-platforms').toString().split(/[\r\n]/)
      try
        json = JSON.parse(line)
        return json['platforms']
  ['web', 'ios', 'android']

platforms = get_platforms()


generate = (template, {saveTo, demands = ['name'], optionsFn}) ->
  argv = yargs.demand(demands).argv

  argParts = _(argv.name).split('/')
  name = argParts.last()
  location = "#{saveTo}/#{argParts.dropRight(1).join('/')}"

  optionsFn ?= (name, location, argv) -> { name: name, location: location, argv: argv }

  gulp.src "templates/#{template}.coffee.ejs"
    .pipe $.plumber(plumberOptions)
    .pipe $.ejs(optionsFn(name, location, argv))
    .pipe $.rename("#{name}.coffee")
    .pipe gulp.dest location


# --- webhelper --- #
webhelper =
  isPending: false
  endListeners: []
  status: ok: true

  beginHandler: ->
    @isPending = true

  errorHandler: (err, caller) ->
    plumberOptions.errorHandler.bind(caller)(err)
    @status = error: err
    @_handleEnd()

  endHandler: ->
    return unless @isPending
    @status = ok: true
    @_handleEnd()

  _handleEnd: ->
    listener(@status) for listener in @endListeners
    @endListeners = []
    @isPending = false

  waitForBuild: ->
    deferred = Q.defer()

    resolveDeferred = (status) ->
      if status?.error?
        deferred.reject(status.error)
      else
        deferred.resolve()

    if @isPending
      @endListeners.push(resolveDeferred)
    else
      resolveDeferred(@status)

    deferred.promise

  runServer: (port = 23904) ->
    app = express()

    app.all '/*', (req, res, next) ->
      res.header("Access-Control-Allow-Origin", "*")
      res.header("Access-Control-Allow-Headers", "X-Requested-With")
      next()

    app.all '/begin', (req, res) =>
      @waitForBuild()
        .then ->
          res.sendStatus(200)
        .fail ->
          res.sendStatus(500)

    app.all '/status', (req, res) =>
      contents =
        if @status.error?
          @status.error.toString()
        else
          'OK'
      ejs.renderFile 'templates/webhelper-status.html.ejs', {contents}, (err, str) ->
        res.send(str)

    app.get '/res/webhelper.js', (req, res) ->
      res.sendFile(__dirname + '/res/webhelper.js')

    app.listen(port)


# --- source tasks --- #
gulp.task 'main-scene.coffee', ->
  sceneName = yargs
    .alias('name', 'scene')
    .default('scene', 'Main')
    .argv.scene

  gulp.src "templates/main-scene.coffee.ejs"
    .pipe $.plumber(plumberOptions)
    .pipe $.ejs(path: "../scenes/#{sceneName}.coffee")
    .pipe $.rename('main-scene.coffee')
    .pipe gulp.dest 'src/__generated__'


gulp.task 'resources.coffee', ->
  gulp.src "templates/resources.coffee.ejs"
    .pipe $.plumber(plumberOptions)
    .pipe $.ejs(files: glob.sync('res/**/*'), _: _, fs: fs)
    .pipe $.rename('resources.coffee')
    .pipe gulp.dest 'src/__generated__'


gulp.task 'scripts', ->
  b = browserify('src/main.coffee', _.extend(browserifyInc.args, debug: true, fast: true))
  browserifyInc(b, cacheFile: './browserify-cache.json')
  webhelper.beginHandler()
  b
    .transform('coffeeify')
    .bundle()
    .on 'error', (err) -> webhelper.errorHandler(err, @)
    .pipe source('src/__generated__/bundle.js')
    .pipe buffer()
    .pipe $.sourcemaps.init(loadMaps: true)
    .pipe $.sourcemaps.write('.')
    .pipe gulp.dest '.'
    .on 'end', (err) -> webhelper.endHandler(err)


gulp.task 'build', (cb) ->
  runSequence ['main-scene.coffee', 'resources.coffee'], 'scripts', cb


# --- generators --- #
gulp.task 'new:test', -> generate 'test', saveTo: 'test'
gulp.task 'new:scene', -> generate 'scene', saveTo: 'src/scenes'
gulp.task 'new:controller', -> generate 'controller', saveTo: 'src/scenes'
gulp.task 'new:model', -> generate 'model', saveTo: 'src/models'
gulp.task 'new:widget', -> generate 'widget', saveTo: 'src/widgets'
gulp.task 'new:view', -> generate 'view', saveTo: 'src/widgets'


# --- test tasks --- #
gulp.task 'test', ->
  gulp.src 'test/**/*.coffee'
    .pipe $.plumber(plumberOptions)
    .pipe $.mocha()


# --- run tasks --- #
gulp.task 'clean', -> del ['src/__generated__']

for platform in platforms
  gulp.task "start:#{platform}", $.shell.task("cocos run -p #{platform}")

  gulp.task "run:#{platform}", (cb) ->
    runSequence 'build', "start:#{platform}", cb

gulp.task 'start', ['start:web']
gulp.task 'run', ['run:web']

gulp.task 'watch:test', ['test'], ->
  gulp.watch ['{test,src}/**/*.{js|coffee}', '!src/__generated__/*'], ['test']

gulp.task 'watch:build', ['build'], ->
  gulp.watch ['src/**/*.{js,coffee}', '!src/__generated__/*'], ['scripts']

gulp.task 'watch:run', ['build'], ->
  webhelper.runServer()
  exec 'cocos run -p web', ->
    $.util.log($.util.colors.cyan('Restarting cocos'))
    setTimeout (-> exec 'cocos run -p web -b null'), 500
  gulp.watch ['src/**/*.{js,coffee}', '!src/__generated__/*'], ['scripts']

gulp.task 'default', ['watch:run']
