events = require "events"
Promise = require "bluebird"
util = require "util"

class MongoLoader extends events.EventEmitter
    constructor: (collection, @query, @projection, options = {}) ->
        @getAsync = Promise.promisify(collection.get).bind(collection)
        @modCheckField = options.modCheckField
        @queryOptions = options.queryOptions || {}
        @default = options.default
        @processor = options.processor || (x) -> x

    loadAsync: (check) ->
        # Use cached file IF we are monitoring OR if we were not asked to check
        return value: @value, loaded: false if @value && !check

        query = @query
        if @modCheckValue
            query = util._extend {}, query
            query[@modCheckField] = $ne: @modCheckValue

        @getAsync query, @projection, @queryOptions
        .bind @
        .then (rv) ->
            if !rv
                if @default
                    @value = @default
                    return value: @value, loaded: true

                err = new Error "No record found in mongo"
                err.code = "ENOENT"
                throw err

            if @modCheckField then @modCheckValue = rv[@modCheckField]

            Promise.bind @
            .then () -> @processor rv
            .then (@value) ->
            return value: @value, loaded: true

    reset: () ->
        @value = @modCheckValue = null

module.exports = MongoLoader
