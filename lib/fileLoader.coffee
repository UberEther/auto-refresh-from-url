events = require "events"
Promise = require "bluebird"
fs = require "fs"
path = require "path"

readFileAsync = fs.readFileAsync || Promise.promisify(fs.readFile).bind(fs)

class FileLoader extends events.EventEmitter
    constructor: (file, options = {}) ->
        @file = path.resolve file
        @doNotMonitor = options.doNotMonitor
        @processor = options.processor || (x) -> x
        @default = options.default
        @readOpts = options.readOpts || { encoding: "utf8", flag: "r" }

    loadAsync: (check) ->
        # Use cached file IF we are monitoring OR if we were not asked to check
        return value: @value, loaded: false if @value && (!@doNotMonitor || !check)

        readFileAsync @file, @readOpts
        .bind @
        .then @processor
        .then (@value) ->
            # Wait till here to setup watch - fs.watch fails if the file does not exist...
            if !@doNotMonitor && !@watch # Initiate file monitor
                @watch = fs.watch @file, { persistent: false, recursive: false }, @reset.bind @
            return value: @value, loaded: true
        .catch (err) ->
            return value: @default, loaded: true if err?.code == "ENOENT" && @default
            throw err

    reset: () ->
        @watch.close() if @watch
        @value = @watch = null

module.exports = FileLoader
