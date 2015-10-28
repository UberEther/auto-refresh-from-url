events = require "events"
Promise = require "bluebird"
request = require "request"

class StaticLoader extends events.EventEmitter
    constructor: (@value) ->

    loadAsync: (check) -> Promise.resolve value: @value, loaded: false

    reset: () ->

module.exports = StaticLoader
