path        = require 'path'
assert      = require 'assert'
{expect}    = require 'chai'
sinon       = require 'sinon'

pn = (pth) -> pth.split('/').join(path.sep)

coffeeCoverage = require("../src/index")

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
testDir = path.resolve __dirname, "../testFixtures/testWithConfig"

extensions = ['.coffee', '.litcoffee', '.coffee.md', '._coffee']
loadedModules = [
    '../testFixtures/testWithExcludes/a/foo.coffee',
    '../testFixtures/testWithExcludes/b/bar.coffee'
]
handlers = {}

{COVERAGE_VAR, log} = require './testConfig'

describe "Coverage tests", ->
    before ->
        for ext in extensions
            handlers[ext] = require.extensions[ext]

    afterEach ->
        # Undo the `register` command
        for ext in extensions
            require.extensions[ext] = handlers[ext]

        # Remove modules we loaded so we can reload them for the next test.
        for mod in loadedModules
            p = path.resolve mod
            if !p of require.cache then console.log "Argh!"
            delete require.cache[path.resolve(__dirname, mod)]

        # Clear coverage
        delete global[COVERAGE_VAR]

    it "should exclude directories specified from the project root when dynamically instrumenting code", ->
        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["/b"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR][pn 'a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR][pn 'b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should exclude directories when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["b"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR][pn 'a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR][pn 'b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should exclude files based on globs when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["**/*r.coffee"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR][pn 'a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR][pn 'b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should exclude files based on globs with leading forward slash from project root when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["/b/*r.coffee"]
            coverageVar: COVERAGE_VAR
            log: log
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        expect(global[COVERAGE_VAR], "Code should have been instrumented").to.exist
        expect(global[COVERAGE_VAR][pn 'a/foo.coffee'], "Should instrument a/foo.coffee").to.exist
        expect(global[COVERAGE_VAR][pn 'b/bar.coffee'], "Should not instrument b/bar.coffee").to.not.exist

    it "should handle nested recursion correctly", ->
        # From https://github.com/benbria/coffee-coverage/pull/37
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            z = 0
            for i in [0...2]
                for j in [0...5]
                    z++

            return z
        """

        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.equal 10

    it "should throw an error if input can't be compiled", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            waka { waka
        """

        expect( ->
            instrumentor.instrumentCoffee("example.coffee", source).js
        ).to.throw(/Could not parse example.coffee.*/)

    it "should throw an error if source folder does not exist", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            waka { waka
        """

        expect( ->
            instrumentor.instrument("./i.do.not.exist", "/tmp/t", {})
        ).to.throw(/Source file .*i\.do\.not\.exist does not exist/)

        expect( ->
            instrumentor.instrumentCoffee("example.coffee", source).js
        ).to.throw(/Could not parse example.coffee.*/)

    it "should throw an error if an invalid instrumentor is specified", ->
        expect( ->
            instrumentor = new coffeeCoverage.CoverageInstrumentor({
                coverageVar: COVERAGE_VAR
                log: log
                instrumentor: 'foo'
            })
        ).to.throw()

    it "should process a streamline file < 1.x", ->
        sinon.spy console, 'warn'
        haveOldStreamline = try require 'streamline/lib/callbacks/transform'

        if !haveOldStreamline
            console.warn "Can only run old streamline test if old streamline is installed"
            return

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/streamlineFiles'
            coverageVar: COVERAGE_VAR
            log: log
            streamlinejs: true
        )

        require '../testFixtures/streamlineFiles/foo._coffee'

        expect(global[COVERAGE_VAR]['foo._coffee']).to.exist
        sinon.assert.callCount(console.warn, 1)
        console.warn.restore()

    it "should post process a file", ->
        postProcessors = [{
            ext: '._fake'
            fn: sinon.spy (compiled, fileName) ->
                compiled += "exports.baz = function() {return 5;}"
        }]

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/streamlineFiles'
            coverageVar: COVERAGE_VAR
            log: log
            postProcessors: postProcessors
        )

        bar = require '../testFixtures/streamlineFiles/bar._fake'

        sinon.assert.callCount(postProcessors[0].fn, 1)
        expect(bar.baz()).to.eq 5
