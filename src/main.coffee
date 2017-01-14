require('coffeescript-accessors').bootstrap()
require('coffeescript-mixins-lodash').bootstrap()

require('./globals.coffee')

# for main.js
window.document ?= {}
window.MainScene = require('./__generated__/main-scene.coffee')
window.g_resources = require('./__generated__/resources.coffee')
