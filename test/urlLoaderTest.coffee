expect = require("chai").expect
http = require "http"

serverHost = "127.0.0.1"
serverPort = 24601
serverUrl = "http://#{serverHost}:#{serverPort}"

describe "UrlLoader", () ->
    UrlLoader = require("../lib").UrlLoader

    server = null
    resultCode = resultType = resultBody = resultPath = resultMethod = resultEtag = resultLastMod = null

    before "Start test server", (done) ->
        server = http.createServer (req, res) ->
            if (resultPath && resultPath != req.url) ||
               (resultMethod && resultMethod != req.method)
                res.writeHead 500, "Content-Type": "text/plain"
                res.end "Invalid parameters for test"
            else if (req.headers["if-none-match"] == resultEtag) ||
                    (req.headers["if-modified-since"] == resultLastMod)
                res.writeHead 304
                res.end "Unmodified"
            else
                headers = "Content-Type": resultType
                if resultEtag then headers.ETag = resultEtag
                if resultLastMod then headers["Last-Modified"] = resultLastMod
                res.writeHead resultCode, headers
                res.end resultBody
        .listen serverPort, serverHost, done

    after "Stop test server", (done) -> if server then server.close done

    it "Should construct correctly with defaults", () ->
        # intentionally not testing request and requestDefaults - can't easily inspect these
        t = new UrlLoader "https://foo.example.com/bar"
        expect(t).to.be.ok
        expect(t.url).to.equal("https://foo.example.com/bar")
        expect(t.ignoreEtag).to.equal(undefined)
        expect(t.ignoreLastModified ).to.equal(undefined)
        expect(t.allowedResultCodes ).to.deep.equal([200])
        expect(t.processor).to.be.ok
        expect(t.processor(t)).to.equal(t)

    it "Should construct correctly with overrides", () ->
        # intentionally not testing request and requestDefaults - can't easily inspect these
        t = new UrlLoader "https://foo.example.com/bar",
            ignoreEtag: true
            ignoreLastModified: true
            processor: () -> 12345
            allowedResultCodes : [1,2,3]
        expect(t).to.be.ok
        expect(t.url).to.equal("https://foo.example.com/bar")
        expect(t.ignoreEtag).to.equal(true)
        expect(t.ignoreLastModified ).to.equal(true)
        expect(t.allowedResultCodes ).to.deep.equal([1,2,3])
        expect(t.processor).to.be.ok
        expect(t.processor(t)).to.equal(12345)

    it "Should reset everything on reset", () ->
        t = new UrlLoader "https://foo.example.com/bar"
        t.value = t.etag = t.lastModified = 1
        t.reset()
        expect(t.value).to.equal(null)
        expect(t.etag).to.equal(null)
        expect(t.lastModified).to.equal(null)

    describe "buildReqOpts", () ->
        it "Should build options without etags or last-modified", () ->
            t = new UrlLoader "https://foo.example.com/bar"
            expect(t.buildReqOpts()).to.deep.equal(url: "https://foo.example.com/bar", headers: {})

        it "Should build options with etags", () ->
            t = new UrlLoader "https://foo.example.com/bar"
            t.etag = "abcde"
            expect(t.buildReqOpts()).to.deep.equal(url: "https://foo.example.com/bar", headers: { "If-None-Match": "abcde"})

        it "Should build options with last-modified", () ->
            t = new UrlLoader "https://foo.example.com/bar"
            t.lastModified = "abcde"
            expect(t.buildReqOpts()).to.deep.equal(url: "https://foo.example.com/bar", headers: { "If-Modified-Since": "abcde"})

    it "Should load a URL if never loaded", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = null
        resultLastMod = null

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: false)
        .then () -> done()
        .catch done

    it "Should throw error on unexpected result code", (done) ->
        resultCode = 201
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = null
        resultLastMod = null

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) -> throw new Error "Unexpected success in unit test"
        .catch (err) ->
            throw err if err.code != "HTTP-Failure"
            expect(err.httpStatusCode).to.equal(201)
            expect(err.httpResponse).to.equal("ABCDE")
        .then () -> done()
        .catch done

    it "Should return cached data if checking but not modified (etag)", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = "xyzzy"
        resultLastMod = null

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: false)
        .then () -> done()
        .catch done

    it "Should return cached data if checking but not modified (last-modified)", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = null
        resultLastMod = "xyzzy"

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: false)
        .then () -> done()
        .catch done

    it "Should return updated data if checking and modified (etag)", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = "xyzzy"
        resultLastMod = null

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            resultBody = "GFHIJ"
            resultEtag = "wxyz"
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value: "GFHIJ", loaded: true)
        .then () -> done()
        .catch done

    it "Should return updated data if checking and modified (last-modified)", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = null
        resultLastMod = "xyzzy"

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            resultBody = "GFHIJ"
            resultLastMod = "wxyz"
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value: "GFHIJ", loaded: true)
        .then () -> done()
        .catch done

    it "Should reload if reset (if not checking)", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = null
        resultLastMod = null

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            t.reset()
            t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
        .then () -> done()
        .catch done

    it "Should stash etag and last mod if enabled", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = "aaaa"
        resultLastMod = "bbbb"

        t = new UrlLoader "#{serverUrl}/"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            expect(t.etag).to.equal("aaaa")
            expect(t.lastModified).to.equal("bbbb")
        .then () -> done()
        .catch done

    it "Should not stash etag if disabled", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = "aaaa"
        resultLastMod = "bbbb"

        t = new UrlLoader "#{serverUrl}/", ignoreEtag: true
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            expect(t.etag).to.equal(undefined)
            expect(t.lastModified).to.equal("bbbb")
        .then () -> done()
        .catch done

    it "Should not stash lastModified if disabled", (done) ->
        resultCode = 200
        resultType = "text/plain"
        resultBody = "ABCDE"
        resultPath = "/"
        resultMethod = "GET"
        resultEtag = "aaaa"
        resultLastMod = "bbbb"

        t = new UrlLoader "#{serverUrl}/", ignoreLastModified: true
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCDE", loaded: true)
            expect(t.etag).to.equal("aaaa")
            expect(t.lastModified).to.equal(undefined)
        .then () -> done()
        .catch done
