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
browserify = require 'browserify'
browserifyInc = require 'browserify-incremental'
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'


# --- utils --- #
plumberOptions =
  errorHandler: (err) ->
    $.util.beep()
    $.util.log(
      $.util.colors.cyan('Plumber') + $.util.colors.red(' found unhandled error:\n'),
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


# --- source tasks --- #
gulp.task 'resources.coffee', ->
  gulp.src "templates/resources.coffee.ejs"
    .pipe $.plumber(plumberOptions)
    .pipe $.ejs(_: require('lodash'), files: fs.readdirSync('res'))
    .pipe $.rename("resources.coffee")
    .pipe gulp.dest 'src'

gulp.task 'scripts', ->
  b = browserify('src/main.coffee', _.extend(browserifyInc.args, debug: true, fast: true))
  browserifyInc(b, cacheFile: './browserify-cache.json')
  b
    .transform('coffeeify')
    .bundle()
    .on('error', plumberOptions.errorHandler)
    .pipe source('dist/bundle.js')
    .pipe buffer()
    .pipe $.sourcemaps.init(loadMaps: true)
    .pipe $.sourcemaps.write('.')
    .pipe gulp.dest '.'

gulp.task 'build', (cb) ->
  runSequence 'resources.coffee', 'scripts', cb


# --- generators --- #
gulp.task 'new:test', -> generate 'test', saveTo: 'test'
gulp.task 'new:scene', -> generate 'scene', saveTo: 'src/scenes'


# --- general tasks --- #
gulp.task 'clean', -> del ['dist']

for platform in platforms
  gulp.task "start:#{platform}", $.shell.task("cocos run -p #{platform}")

  gulp.task "run:#{platform}", (cb) ->
    runSequence 'build', "start:#{platform}", cb

gulp.task 'test', ->
  gulp.src 'test/**/*.coffee'
    .pipe $.plumber(plumberOptions)
    .pipe $.mocha()

gulp.task 'watch:test', ['test'], ->
  gulp.watch '{test,src}/**/*.{js|coffee}', ['test']

gulp.task 'watch:build', ['build'], ->
  gulp.watch 'src/**/*.{js,coffee}', ['scripts']

gulp.task 'watch:run', ['build'], ->
  exec 'cocos run -p web', ->
    $.util.log($.util.colors.cyan('Restarting cocos'))
    setTimeout (-> exec 'cocos run -p web -b null'), 500

  gulp.watch 'src/**/*.{js,coffee}', ['scripts']

gulp.task 'default', ['watch:run']

