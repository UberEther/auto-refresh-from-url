expect = require("chai").expect
Promise = require "bluebird"

describe "CachedLoader", () ->
    CachedLoader = require("../lib").CachedLoader

    actions = []
    childLoader =
        reset: () -> actions.push "reset"
        loadAsync: (x) ->
            actions.push if x then "check" else "cache"
            return Promise.resolve value: actions.length, loaded: !!x

    it "Should construct correctly with defaults", () ->
        t = new CachedLoader childLoader
        expect(t.childLoader).to.equal(childLoader)
        expect(t.doNotCheckDuration).to.equal(5*60*1000)
        expect(t.refreshDuration).to.equal(1*24*60*60*1000)
        expect(t.expireDuration).to.equal(7*24*60*60*1000)
        expect(t.console).to.equal(console)
        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotCheckBefore).to.equal(0)

    it "Should construct correctly with overrides (numeric durations)", () ->
        foo = { a:1 }
        t = new CachedLoader childLoader,
            doNotCheckDuration: 1
            refreshDuration: 2
            expireDuration: 3
            console: foo
        expect(t.childLoader).to.equal(childLoader)
        expect(t.doNotCheckDuration).to.equal(1)
        expect(t.refreshDuration).to.equal(2)
        expect(t.expireDuration).to.equal(3)
        expect(t.console).to.equal(foo)
        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotCheckBefore).to.equal(0)

    it "Should construct correctly with overrides (string durations)", () ->
        foo = { a:1 }
        t = new CachedLoader childLoader,
            doNotCheckDuration: "1s"
            refreshDuration: "2s"
            expireDuration: "3s"
            console: foo
        expect(t.childLoader).to.equal(childLoader)
        expect(t.doNotCheckDuration).to.equal(1000)
        expect(t.refreshDuration).to.equal(2000)
        expect(t.expireDuration).to.equal(3000)
        expect(t.console).to.equal(foo)
        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotCheckBefore).to.equal(0)

    it "Should reset values on reset", () ->
        actions = []
        t = new CachedLoader childLoader

        t.refreshAt = t.expireAt = t.doNotExpireBefore = 1
        t.reset()

        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotCheckBefore).to.equal(0)
        expect(actions).to.deep.equal(["reset"])

    it "Should always initial load with check", (done) ->
        actions = []
        t = new CachedLoader childLoader
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value:2, loaded: true)
            expect(actions).to.deep.equal(["reset", "check"])
        .then () -> done()
        .catch done

    it "Should not allow recheck until time is passed", (done) ->
        actions = []
        t = new CachedLoader childLoader, doNotCheckDuration: 50
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value:2, loaded: true)
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value:3, loaded: false)
        .delay(55)
        .then () -> t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value:4, loaded: true)
            expect(actions).to.deep.equal(["reset", "check", "cache", "check"])
        .then () -> done()
        .catch done

    it "Should not allow multiple concurrent checks", (done) ->
        actions = []
        t = new CachedLoader childLoader

        Promise.props a: t.loadAsync(true), b: t.loadAsync(true)
        .then (rv) ->
            expect(rv.a).to.deep.equal(value:2, loaded: true)
            expect(rv.b).to.deep.equal(value:2, loaded: true)
            expect(actions).to.deep.equal(["reset", "check"])
        .then () -> done()
        .catch done

    it "Should background refresh when the refresh time expires", (done) ->
        actions = []
        t = new CachedLoader childLoader, doNotCheckDuration: 0, refreshDuration: 50
        t.loadAsync()
        .delay(55)
        .then () -> t.loadAsync()
        .delay(50)
        .then () -> expect(actions).to.deep.equal(["reset", "check", "cache", "check"])
        .then () -> done()
        .catch done

    it "Should sync refresh when the expiration time expires", (done) ->
        actions = []
        t = new CachedLoader childLoader, doNotCheckDuration: 0, expireDuration: 50
        t.loadAsync()
        .delay(55)
        .then () -> t.loadAsync()
        .delay(50)
        .then () -> expect(actions).to.deep.equal(["reset", "check", "reset", "cache"])
        .then () -> done()
        .catch done

    it "Should emit background error events", (done) ->
        error = new Error "UnitTest"
        actions = []
        errorLoader =
            reset: childLoader.reset
            loadAsync: () ->
                if actions.length > 2 then throw error
                childLoader.loadAsync()

        t = new CachedLoader errorLoader, doNotCheckDuration: 0, refreshDuration: 50
        t.on "backgroundRefreshError", (err) -> actions.push err

        t.loadAsync()
        .delay(55)
        .then () -> t.loadAsync()
        .delay(50)
        .then () -> expect(actions).to.deep.equal(["reset", "cache", "cache", error])
        .then () -> done()
        .catch done

    it "Should log background error to console if no event handlers", (done) ->
        error = new Error "UnitTest"
        actions = []
        errorLoader =
            reset: childLoader.reset
            loadAsync: () ->
                if actions.length > 2 then throw error
                childLoader.loadAsync()

        testConsole = warn: (a) -> actions.push a

        t = new CachedLoader errorLoader, doNotCheckDuration: 0, refreshDuration: 50, console: testConsole
        t.loadAsync()
        .delay(55)
        .then () -> t.loadAsync()
        .delay(50)
        .then () -> expect(actions).to.deep.equal(["reset", "cache", "cache", "Unhandled error in cached loader: #{error.stack}"])
        .then () -> done()
        .catch done
