events = require "events"
Promise = require "bluebird"
ms = require "ms"
_request = require "request"

# Promisify request if needed
if !_request.getAsync then Promise.promisifyAll _request
if !_request.requestAsync then _request.requestAsync = Promise.promisify _request

toMillis = (x) -> typeof x == "number" ? x : ms(x)

class AutoRefreshFromUrl extends events.EventEmitter
    url = undefined
    request = undefined
    doNotRefreshDuration = undefined
    refreshDuration = undefined
    expireDuration = undefined
    refreshAt = undefined
    expireAt = undefined
    doNotRefreshBefore = undefined
    lastModified = undefined
    etag = undefined
    refreshPromise = undefined
    payload = undefined

    constructor: (options = {}) ->
        url = options.url
        request = options.request || request.defaults(options.requestDefaults || { json: true, method: "GET" })
        doNotRefreshDuration = toMillis options.doNotRefreshDuration || "5m"
        refreshDuration = toMillis options.refreshDuration || "1d"
        expireDuration = toMillis options.expireDuration || "7d"
        refreshAt = expireAt = if url then Number.MAX_SAFE_INTEGER else 0
        doNotRefreshBefore = 0

    refreshIfNeededAsync: () ->
        now = Date.now()
        if refreshAt < now
            refreshNowAsync()
            if expireAt < now then return refreshPromise
            else refreshPromise.catch (err) ->
                if !@emit "backgroundUrlRefreshError", err
                    console.warn "Unhandled error refreshing: #{err.stack || err.message || err}"
        return Promise.bind @, payload

    refreshNowAsync: (force) ->
        # Only 1 load at a time...
        if refreshPromise then return refreshPromise

        # Only valid if a URL is specified or we are not forcing and it is before the doNotRefreshBefore
        return Promise.bind @, payload if !force && Date.now() < doNotRefreshBefore

        if !url
            if payload && !force then return Promise.bind @, payload
            refreshPromise = Promise.bind @
            .then () -> @processUrlData null, null
            .then (rv) ->
                doNotRefreshBefore = Date.now() + doNotRefreshDuration
                payload = rv
                return rv
            .finally () -> refreshPromise = null
            return refreshPromise

        promise = refreshPromise = Promise.bind @
        .then () -> @prepareRefreshRequest
        .then (reqOpts) ->request.requestAsync reqOpts
        .spread (res, raw) ->
            doNotRefreshBefore = Date.now() + doNotRefreshDuration
            return payload if res.statusCode == 304 # Not modified...

            Promise.bind @
            .then () -> processUrlData res, raw
            .then (rv) ->
                now = Date.now()
                refreshAt = now + @refreshDuration
                expireAt = now + @expireDuration
                etag = res.headers.etag
                lastModified = res.headers["last-modified"]
                payload = rv
                return rv
        .finally () -> refreshPromise = null

        return promise

    prepareRefreshRequest: () -> # May return value or promise
        rv = url: url

        # Set headers for conditional refreshes using etag or last-modified
        if etag then rv.headers["If-None-Match"] = etag
        if lastModified then rv.headers["If-Modified-Since"] = lastModified

        return rv

    processUrlData: (res, raw) -> # May return value or promise
        if res.statusCode != 200
            err = new Error "Failed to refresh url - status code: #{res.statusCode}: #{url}"
            err.rawResponse = raw
            throw err
        return raw

AutoRefreshFromUrl.request = _request

module.exports = AutoRefreshFromUrl