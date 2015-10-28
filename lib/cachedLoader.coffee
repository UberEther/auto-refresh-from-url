events = require "events"
Promise = require "bluebird"
ms = require "ms"

toMillis = (x) -> if typeof x == "number" then x else ms(x)

class CachedLoader extends events.EventEmitter
    constructor: (@childLoader, options = {}) ->
        @doNotCheckDuration = toMillis if options.doNotCheckDuration? then options.doNotCheckDuration else "5m"
        @refreshDuration = toMillis if options.refreshDuration? then options.refreshDuration else "1d"
        @expireDuration = toMillis if options.expireDuration? then options.expireDuration else "7d"
        @refreshAt = @expireAt = @doNotCheckBefore = 0
        @console = options.console || console

    _loadFromChildAsync: (check) ->
        now = Date.now()

        # If never loaded, force a check
        check ||= !@refreshAt
        # Only allow a check IF we are not before the doNotCheckBefore (do a reset() to force)
        check &&= Date.now() >= @doNotCheckBefore

        # Update doNotCheckBefore if we are checking
        if check then @doNotCheckBefore = Date.now() + @doNotCheckDuration

        # Make the load
        @childLoader.loadAsync check
        .bind @
        .then (rv) ->
            # If we checked or loaded something then update timers
            if check || rv.loaded
                now = Date.now()
                # Update do not refresh to account for the time it took to load...
                @doNotCheckBefore = now + @doNotCheckDuration
                @refreshAt = now + @refreshDuration
                @expireAt = now + @expireDuration

            return rv

    loadAsync: (check) ->
        now = Date.now()

        # Only 1 load at a time...
        if @refreshPromise then return @refreshPromise

        # Reset if we are expired...
        if @expireAt <= now then @childLoader.reset()

        # Load...
        @refreshPromise = @_loadFromChildAsync check
        .bind @
        .then (rv) ->
            # Check to see if we need a BG refresh
            if !check && !rv.loaded && @refreshAt <= Date.now() && !@bgPromise
                @bgPromise = Promise.bind @
                .then () -> @_loadFromChildAsync true
                .finally @bgPromise = null
                .catch (err) ->
                    # Handle background refresh errors
                    if !@emit "backgroundRefreshError", err
                        @console.warn "Unhandled error in cached loader: #{err.stack || err.message || err}"

            return value: rv.value, loaded: rv.loaded
            
        .finally () -> @refreshPromise = null

        return @refreshPromise

    reset: () ->
        @refreshAt = @expireAt = @doNotCheckBefore = 0
        @childLoader.reset()

module.exports = CachedLoader
