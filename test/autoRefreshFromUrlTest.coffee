http = require "http"
expect = require("chai").expect
AutoRefresh = require "../lib"

serverHost = "127.0.0.1"
serverPort = 24601
serverUrl = "http://#{serverHost}:#{serverPort}"

describe "AutoRefresh", () ->
    server = null
    resultCode = resultType = resultBody = resultPath = resultMethod = null

    before "Start test server", (done) ->
        server = http.createServer (req, res) ->

            if (resultPath && resultPath != req.url) ||
               (resultMethod && resultMethod != req.method)
                res.writeHead 500, "Content-Type": "text/plain"
                res.end "Invalid parameters for test"
            else
                res.writeHead resultCode, "Content-Type": resultType
                res.end resultBody
        .listen 24601, "127.0.0.1", done

    after "Stop test server", (done) -> if server then server.close done

    it "should construct with correct defaults", () ->
        t = new AutoRefresh
        expect(t.requestAsync).to.be.ok
        expect(t.url).to.equal(undefined)
        expect(t.doNotRefreshDuration).to.equal(5 * 60 * 1000)
        expect(t.refreshDuration).to.equal(24 * 60 * 60 * 1000)
        expect(t.expireDuration).to.equal(7 * 24 * 60 * 60 * 1000)
        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotRefreshBefore).to.equal(0)
        expect(t.console).to.equal(console)

    it "should construct with correct overrides", (done) ->
        t2 = (cb) -> cb null, "test: 2"
        t3 = test: 3
        t = new AutoRefresh
            url: "url"
            request: t2
            doNotRefreshDuration: "1m"
            refreshDuration: "2m"
            expireDuration: "3m"
            console: t3

        expect(t.requestAsync).to.be.ok
        expect(t.url).to.equal("url")
        expect(t.doNotRefreshDuration).to.equal(1 * 60 * 1000)
        expect(t.refreshDuration).to.equal(2 * 60 * 1000)
        expect(t.expireDuration).to.equal(3 * 60 * 1000)
        expect(t.refreshAt).to.equal(0)
        expect(t.expireAt).to.equal(0)
        expect(t.doNotRefreshBefore).to.equal(0)
        expect(t.console).to.equal(t3)

        t.requestAsync()
        .then (rv) -> expect(rv).to.equal("test: 2")
        .then () -> done()
        .catch done

    it "should construct with numeric durations", () ->
        t = new AutoRefresh
            doNotRefreshDuration: 1
            refreshDuration: 2
            expireDuration: 3

        expect(t.doNotRefreshDuration).to.equal(1)
        expect(t.refreshDuration).to.equal(2)
        expect(t.expireDuration).to.equal(3)

    it "should load from URL", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh url: serverUrl+resultPath

        t.refreshIfNeededAsync()
        .then (rv) -> expect(rv).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should use cache", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh url: serverUrl+resultPath
        t2 = undefined

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            resultPath = "/bar"
            t.refreshIfNeededAsync()
        .then (rv) -> expect(rv).to.equal(t2)
        .then () -> done()
        .catch done

    it "should background refresh", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            t.refreshIfNeededAsync()
            expect(t.refreshPromise).to.be.ok
            expect(t.refreshNowAsync()).to.equal(t.refreshPromise)
            t.refreshPromise.then (rv) -> expect(rv).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should handle errors on initial refresh (default)", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0
            console: warn: () -> done()

        t.prepareRefreshRequest = () -> throw new Error "Unit Test"
        t.refreshIfNeededAsync()
        .then () -> throw new Error "Expected test to fail"
        .catch (err) ->
            if err?.message == "Unit Test" then done()
            else done err

    it "should handle errors on initial refresh (event)", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0

        t.on "backgroundUrlRefreshError", () -> done()

        t.prepareRefreshRequest = () -> throw new Error "Unit Test"
        t.refreshIfNeededAsync()
        .then () -> throw new Error "Expected test to fail"
        .catch (err) ->
            if err?.message == "Unit Test" then done()
            else done err

    it "should ignore errors on subsequent refresh", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0
            console: warn: () -> done()

        t.refreshIfNeededAsync()
        .then (rv1) ->
            t.prepareRefreshRequest = () -> throw new Error "Unit Test"
            t.refreshIfNeededAsync()
            .then (rv2) -> expect(rv2).to.equal(rv1)

    it "should foreground refresh on expire", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0
            expireDuration: 0
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            t.refreshIfNeededAsync()
            .then (rv) -> expect(rv).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should not allow multiple concurrent refreshes", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            refreshDuration: 0
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            p = t.refreshNowAsync true
            p2 = t.refreshNowAsync true
            expect(p).is.ok.and.equals(p2)
            p.then (rv) -> expect(rv).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should not allow refreshes if refreshDuration has not passed", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 100
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            t.refreshNowAsync()
            .then (rv2) -> expect(rv2).to.equal(rv)
            .delay 100
            .then () -> t.refreshNowAsync()
            .then (rv3) -> expect(rv3).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should ignore doNotRefreshDuration if forced", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 100
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            t.refreshNowAsync(true)
            .then (rv2) -> expect(rv2).to.deep.equal(result)
        .then () -> done()
        .catch done

    it "should honor 304 responses", (done) ->
        resultCode = 200
        resultType = "text/json"
        result = { test: "ABCDE" }
        resultBody = JSON.stringify result
        resultMethod = "GET"
        resultPath = "/foo?a=1"

        t = new AutoRefresh
            url: serverUrl+resultPath
            doNotRefreshDuration: 0
            refreshDuration: 0
        t2 = null

        t.refreshIfNeededAsync()
        .then (rv) ->
            t2 = rv
            expect(rv).to.deep.equal(result)

            resultCode = 304
            result = { test: "ABCDEFG" }
            resultBody = JSON.stringify result

            t.refreshNowAsync()
            .then (rv2) -> expect(rv2).to.equal(rv)
        .then () -> done()
        .catch done

    it "should work with no url", (done) ->
        t = new AutoRefresh

        t.processUrlData = () -> return "ABCDE"

        t.refreshIfNeededAsync()
        .then (rv) -> expect(rv).to.equal("ABCDE")
        .then () -> done()
        .catch done

    describe "prepareRefreshRequest", () ->
        it "should generate requestOptions correctly", () ->
            t = new AutoRefresh

            rv = t.prepareRefreshRequest()
            expect(rv).to.deep.equal(
                url: undefined
                headers: {}
            )

            t.url = "Test1"
            rv = t.prepareRefreshRequest()
            expect(rv).to.deep.equal(
                url: "Test1"
                headers: {}
            )
            
            t.etag = "Test2"
            rv = t.prepareRefreshRequest()
            expect(rv).to.deep.equal(
                url: "Test1"
                headers:
                    "If-None-Match": "Test2"
            )
            
            t.etag = null
            t.lastModified = "Test3"
            rv = t.prepareRefreshRequest()
            expect(rv).to.deep.equal(
                url: "Test1"
                headers:
                    "If-Modified-Since": "Test3"
            )

    describe "processUrlData", () ->
        it "should return data as-is on http 200", () ->
            t = new AutoRefresh

            rv = t.processUrlData(statusCode: 200)
            expect(rv).to.equal(undefined)

            rv = t.processUrlData {statusCode: 200}, "XYZZY"
            expect(rv).to.equal("XYZZY")

            t2 = test: "ABC"
            rv = t.processUrlData {statusCode: 200}, t2
            expect(rv).to.equal(t2)

        it "should throw error on any non-http 200", () ->
            t = new AutoRefresh
                url: "Test1"

            try
                t.processUrlData(statusCode: 404)
                throw Error "Test failed: Method did not throw exception"
            catch err
                expect(err instanceof Error).to.be.true
                expect(err.message).to.equal("Failed to refresh url - status code: 404: Test1")

        it "should return raw data on non-http requests", () ->
            t = new AutoRefresh

            rv = t.processUrlData()
            expect(rv).to.equal(undefined)

            rv = t.processUrlData null, "XYZZY"
            expect(rv).to.equal("XYZZY")

            t2 = test: "ABC"
            rv = t.processUrlData null, t2
            expect(rv).to.equal(t2)
