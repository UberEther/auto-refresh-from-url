events = require "events"
Promise = require "bluebird"
_request = require "request"

class UrlLoader extends events.EventEmitter
    constructor: (@url, options = {}) ->
        request = options.request || UrlLoader.request.defaults(options.requestDefaults || { json: true, method: "GET" })
        @requestAsync = Promise.promisify(request).bind(request)
        @ignoreEtag = options.ignoreEtag
        @ignoreLastModified = options.ignoreLastModified
        @allowedResultCodes = options.allowedResultCodes || [ 200 ]
        @processor = options.processor || (x) -> x

    loadAsync: (check) ->
        return value: @value, loaded: false if @value && !check

        reqOpts = @buildReqOpts()

        @requestAsync reqOpts
        .bind @
        .spread (res, raw) ->
            return { value: @value, loaded: false } if res.statusCode == 304 # Not modified...

            if @allowedResultCodes.indexOf(res.statusCode) < 0
                err = new Error "Failed to load url - status code: #{res.statusCode}: #{reqOpts.url}"
                err.code = "HTTP-Failure"
                err.httpStatusCode = res.statusCode
                err.httpResponse = raw
                throw err

            Promise.bind @, raw
            .then @processor
            .then (@value) ->
                @etag = res.headers.etag if !@ignoreEtag
                @lastModified = res.headers["last-modified"] if !@ignoreLastModified
                return value: @value, loaded: true

    reset: () ->
        @value = @etag = @lastModified = null

    buildReqOpts: () ->
        reqOpts = url: @url, headers: {}
        if @etag then reqOpts.headers["If-None-Match"] = @etag
        if @lastModified then reqOpts.headers["If-Modified-Since"] = @lastModified

        return reqOpts


UrlLoader.request = _request

module.exports = UrlLoader
