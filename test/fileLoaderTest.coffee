expect = require("chai").expect
fs = require "fs"
path = require "path"

describe "FileLoader", () ->
    FileLoader = require("../lib").FileLoader

    packageJsonBuffer = fs.readFileSync "package.json"
    packageJsonString = packageJsonBuffer.toString "utf8"
    packageJsonObject = JSON.parse packageJsonString

    it "Should construct correctly with defaults", () ->
        t = new FileLoader "fn"
        expect(t).to.be.ok
        expect(t.file).to.equal(path.resolve("fn"))
        expect(t.doNotMonitor).to.equal(undefined)
        expect(t.default).to.equal(undefined)
        expect(t.readOpts).to.deep.equal(encoding: "utf8", flag: "r")
        expect(t.processor).to.be.ok
        expect(t.processor(t)).to.equal(t)

    it "Should construct correctly with overrides", () ->
        t = new FileLoader "fn",
            doNotMonitor: true
            processor: () -> 12345
            default: 67890
            readOpts: {}

        expect(t).to.be.ok
        expect(t.file).to.equal(path.resolve("fn"))
        expect(t.doNotMonitor).to.equal(true)
        expect(t.default).to.equal(67890)
        expect(t.readOpts).to.deep.equal({})
        expect(t.processor).to.be.ok
        expect(t.processor(t)).to.equal(12345)

    it "Should use default if file does not exist", (done) ->
        t = new FileLoader "does-not-exist.txt", default: 67890
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: 67890, loaded: true)
        .then () -> done()
        .catch done

    it "Should throw execption if file does not exist and no default", (done) ->
        t = new FileLoader "does-not-exist.txt"
        t.loadAsync()
        .then (rv) -> throw new Error "Test was expected to throw exception"
        .catch (err) ->
            throw err if err.code != "ENOENT"
        .then () -> done()
        .catch done

    it "Should load file if not loaded", (done) ->
        t = new FileLoader "package.json"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: packageJsonString, loaded: true)
        .then () -> done()
        .catch done

    it "Should load file only once if not modified", (done) ->
        t = new FileLoader "package.json"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: packageJsonString, loaded: true)
            t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: packageJsonString, loaded: false)
        .then () -> done()
        .catch done

    it "Should load file after reset", (done) ->
        t = new FileLoader "package.json"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: packageJsonString, loaded: true)
            t.reset()
            t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: packageJsonString, loaded: true)
        .then () -> done()
        .catch done


    it "Should load file if modified when monitoring", (done) ->
        t = new FileLoader "t.txt"
        fs.writeFileSync "t.txt", "ABCD", encoding: "utf8"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: true)
            fs.writeFileSync "t.txt", "EFGH", encoding: "utf8"
        .delay 50 # Allow time for the write to propogate
        .then () -> t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "EFGH", loaded: true)
        .then () -> done()
        .catch done
        .finally () -> fs.unlinkSync "t.txt"

    it "Should not load file if modified when not monitoring (with check=false)", (done) ->
        t = new FileLoader "t.txt", doNotMonitor: true
        fs.writeFileSync "t.txt", "ABCD", encoding: "utf8"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: true)
            fs.writeFileSync "t.txt", "EFGH", encoding: "utf8"
        .delay 50 # Allow time for the write to propogate
        .then () -> t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: false)
        .then () -> done()
        .catch done
        .finally () -> fs.unlinkSync "t.txt"

    it "Should load file if modified when not monitoring (with check=true)", (done) ->
        t = new FileLoader "t.txt", doNotMonitor: true
        fs.writeFileSync "t.txt", "ABCD", encoding: "utf8"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: true)
            fs.writeFileSync "t.txt", "EFGH", encoding: "utf8"
        .delay 50 # Allow time for the write to propogate
        .then () -> t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: false)
            t.loadAsync(true)
        .then (rv) ->
            expect(rv).to.deep.equal(value: "EFGH", loaded: true)
        .then () -> done()
        .catch done
        .finally () -> fs.unlinkSync "t.txt"

    it "Should load file if modified after a reset", (done) ->
        t = new FileLoader "t.txt", doNotMonitor: true
        fs.writeFileSync "t.txt", "ABCD", encoding: "utf8"
        t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: true)
            fs.writeFileSync "t.txt", "EFGH", encoding: "utf8"
        .delay 50 # Allow time for the write to propogate
        .then () -> t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "ABCD", loaded: false)
            t.reset()
            t.loadAsync()
        .then (rv) ->
            expect(rv).to.deep.equal(value: "EFGH", loaded: true)
        .then () -> done()
        .catch done
        .finally () -> fs.unlinkSync "t.txt"

