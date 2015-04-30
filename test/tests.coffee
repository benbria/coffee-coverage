path = require 'path'
assert = require 'assert'
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

        assert global[COVERAGE_VAR]?, "Code should have been instrumented"
        assert ('a/foo.coffee' of global[COVERAGE_VAR]), "Should instrument a/foo.coffee"
        assert !('b/bar.coffee' of global[COVERAGE_VAR]), "Should not instrument b/bar.coffee"

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

        assert global[COVERAGE_VAR]?, "Code should have been instrumented"
        assert ('a/foo.coffee' of global[COVERAGE_VAR]), "Should instrument a/foo.coffee"
        assert !('b/bar.coffee' of global[COVERAGE_VAR]), "Should not instrument b/bar.coffee"

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

        code = instrumentor.instrumentCoffee("example.coffee", source).js

        global[COVERAGE_VAR] = {"example.coffee": {}}
        z = eval code
        assert.equal z, 10
