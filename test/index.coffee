expect = require("chai").expect
rewire = require "rewire"

describe "/lib/index.js", () ->
    it "should load without errors", () ->
        t = rewire "../lib"
        expect(t).to.be.ok

    it "should expose all expected classes", () ->
        t = rewire "../lib"
        expect(t.CachedLoader).to.be.ok
        expect(t.FileLoader).to.be.ok
        expect(t.StaticLoader).to.be.ok
        expect(t.UrlLoader).to.be.ok
