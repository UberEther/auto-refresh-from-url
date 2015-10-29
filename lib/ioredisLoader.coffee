events = require "events"
Promise = require "bluebird"

class IORedisLoader extends events.EventEmitter
    constructor: (ioRedis, key, options) ->
        @getAsync = ioRedis.get.bind ioRedis, key
        @default = options.default
        @processor = options.processor || (x) -> x

    loadAsync: (check) ->
        # Use cached file IF we are monitoring OR if we were not asked to check
        return value: @value, loaded: false if @value && !check

        @getAsync()
        .bind @
        .then (rv) ->
            if !rv
                if @default
                    @value = @default
                    return value: @value, loaded: true

                err = new Error "No record found in mongo"
                err.code = "ENOENT"
                throw err
                
            Promise.bind @
            .then () -> @processor rv
            .then (@value) ->
            return value: @value, loaded: true

    reset: () ->
        @value = null

module.exports = IORedisLoader
