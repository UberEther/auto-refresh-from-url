events = require "events"
Promise = require "bluebird"
ms = require "ms"
request = require "request"

toMillis = (x) -> typeof x == "number" ? x : ms(x)

promisifyRequest = (request) ->
    # Promisify request if needed
    if !request.getAsync then Promise.promisifyAll request
    if !request.requestAsync then request.requestAsync = Promise.promisify request
promisifyRequest request

class AutoRefreshFromUrl extends events.EventEmitter
    constructor: (options = {}) ->
        @url = options.url
        
        @request = options.request || AutoRefreshFromUrl.request.defaults(options.requestDefaults || { json: true, method: "GET" })
        @doNotRefreshDuration = toMillis options.doNotRefreshDuration || "5m"
        @refreshDuration = toMillis options.refreshDuration || "1d"
        @expireDuration = toMillis options.expireDuration || "7d"
        @refreshAt = @expireAt = if @url then 0 else Number.MAX_SAFE_INTEGER
        @doNotRefreshBefore = 0
        @console = options.console || console

        promisifyRequest @request # Promisify request if needed

    refreshIfNeededAsync: () ->
        now = Date.now()
        if @refreshAt < now
            promise = @refreshNowAsync()
            if @expireAt < now then return promise
            else promise.catch (err) ->
                if !@emit "backgroundUrlRefreshError", err
                    @console.warn "Unhandled error refreshing: #{err.stack || err.message || err}"
        
        return Promise.bind @, @payload

    refreshNowAsync: (force) ->
        # Only 1 load at a time...
        if @refreshPromise then return @refreshPromise

        # Only valid if a URL is specified or we are not forcing and it is before the doNotRefreshBefore
        return Promise.bind @, @payload if !force && Date.now() < @doNotRefreshBefore

        if !@url
            if @payload && !force then return Promise.bind @, @payload
            @refreshPromise = Promise.bind @
            .then () -> @processUrlData null, null
            .then (rv) ->
                @doNotRefreshBefore = Date.now() + @doNotRefreshDuration
                @payload = rv
                return rv
            .finally () -> @refreshPromise = null
            return @refreshPromise

        @refreshPromise = Promise.bind @
        .then @prepareRefreshRequest
        .then (reqOpts) -> @request.requestAsync reqOpts
        .spread (res, raw) ->
            @doNotRefreshBefore = Date.now() + @doNotRefreshDuration
            return @payload if res.statusCode == 304 # Not modified...

            Promise.bind @, [res, raw]
            .spread @processUrlData
            .then (rv) ->
                now = Date.now()
                @refreshAt = now + @refreshDuration
                @expireAt = now + @expireDuration
                @etag = res.headers.etag
                @lastModified = res.headers["last-modified"]
                @payload = rv
                return rv
        .finally () -> @refreshPromise = null

    prepareRefreshRequest: () -> # May return value or promise
        rv = url: @url

        # Set headers for conditional refreshes using etag or last-modified
        if @etag then rv.headers["If-None-Match"] = @etag
        if @lastModified then rv.headers["If-Modified-Since"] = @lastModified

        return rv

    processUrlData: (res, raw) -> # May return value or promise
        if res.statusCode != 200
            err = new Error "Failed to refresh url - status code: #{res.statusCode}: #{url}"
            err.rawResponse = raw
            throw err
        return raw

AutoRefreshFromUrl.request = request

module.exports = AutoRefreshFromUrl