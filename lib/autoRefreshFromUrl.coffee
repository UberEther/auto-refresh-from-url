events = require "events"
Promise = require "bluebird"
ms = require "ms"
request = require "request"

toMillis = (x) -> if typeof x == "number" then x else ms(x)

promisifyRequest = (request) -> request.requestAsync ||= Promise.promisify request
promisifyRequest request

class AutoRefreshFromUrl extends events.EventEmitter
    constructor: (options = {}) ->
        @url = options.url
        
        @request = options.request || AutoRefreshFromUrl.request.defaults(options.requestDefaults || { json: true, method: "GET" })
        @doNotRefreshDuration = toMillis if options.doNotRefreshDuration? then options.doNotRefreshDuration else "5m"
        @refreshDuration = toMillis if options.refreshDuration? then options.refreshDuration else "1d"
        @expireDuration = toMillis if options.expireDuration? then options.expireDuration else "7d"
        @refreshAt = @expireAt = @doNotRefreshBefore = 0
        @console = options.console || console

        promisifyRequest @request # Promisify request if needed

    refreshIfNeededAsync: () ->
        now = Date.now()
        if @refreshAt <= now
            expired = @expireAt <= now
            promise = @refreshNowAsync expired
            if expired then return promise
        
        return Promise.bind @, @payload

    refreshNowAsync: (force) ->
        # Only 1 load at a time...
        if @refreshPromise then return @refreshPromise

        # Ensure we are forcing OR it is after the doNotRefreshBefore
        return Promise.bind @, @payload if !force && Date.now() < @doNotRefreshBefore

        @refreshPromise = Promise.bind @
        .then () ->
            # Set do not refresh first thing in case somehting fails...
            @doNotRefreshBefore = Date.now() + @doNotRefreshDuration
            @prepareRefreshRequest @payload
        .then (reqOpts) ->
            if reqOpts?.url then @request.requestAsync reqOpts
            else [null, null]
        .spread (res, raw) ->
            # Reset do not refresh to account for the time it took to load...
            @doNotRefreshBefore = Date.now() + @doNotRefreshDuration
            return @payload if res?.statusCode == 304 # Not modified...

            Promise.bind @, [res, raw, @payload]
            .spread @processUrlData
            .then (rv) ->
                now = Date.now()
                @refreshAt = now + @refreshDuration
                @expireAt = now + @expireDuration
                @etag = res?.headers.etag
                @lastModified = res?.headers["last-modified"]
                @payload = rv
                return rv

        .catch (err) ->
            if force then throw err
            if !@emit "backgroundUrlRefreshError", err
                @console.warn "Unhandled error refreshing: #{err.stack || err.message || err}"
            return @payload
            
        .finally () -> @refreshPromise = null

    prepareRefreshRequest: (oldPayload) -> # May return value or promise
        rv = url: @url, headers: {}

        # Set headers for conditional refreshes using etag or last-modified
        if @etag then rv.headers["If-None-Match"] = @etag
        if @lastModified then rv.headers["If-Modified-Since"] = @lastModified

        return rv

    processUrlData: (res, raw, oldPayload) -> # May return value or promise
        if res && res.statusCode != 200
            err = new Error "Failed to refresh url - status code: #{res.statusCode}: #{@url}"
            err.rawResponse = raw
            throw err
        return raw

AutoRefreshFromUrl.request = request

module.exports = AutoRefreshFromUrl