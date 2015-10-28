expect = require("chai").expect

describe "StaticLoader", () ->
    StaticLoader = require("../lib").StaticLoader

    it "Should construct correctly", () ->
        t = new StaticLoader "fn"
        expect(t).to.be.ok
        expect(t.value).to.equal("fn")

    it "Should return the value even after reset", (done) ->
        t = new StaticLoader "fn"
        expect(t).to.be.ok
        expect(t.value).to.equal("fn")

        t.loadAsync()
        .then (rv) ->
            expect(t.value).to.equal("fn")
            t.reset()
            t.loadAsync()
        .then (rv) ->
            expect(t.value).to.equal("fn")
        .then () -> done()
        .catch done
