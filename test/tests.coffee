path = require 'path'
assert = require 'assert'
coffeeCoverage = require("../src/coffeeCoverage")

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
testDir = path.resolve __dirname, "../testFixtures/testWithConfig"

extensions = ['.coffee', '.litcoffee', '.coffee.md', '._coffee']
loadedModules = [
    '../testFixtures/testWithExcludes/a/foo.coffee',
    '../testFixtures/testWithExcludes/b/bar.coffee'
]
handlers = {}

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
        delete global._$jscoverage

    it "should exclude directories specified from the project root when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["/b"]
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        assert _$jscoverage?, "Code should have been instrumented"
        assert ('a/foo.coffee' of _$jscoverage), "Should instrument a/foo.coffee"
        assert !('b/bar.coffee' of _$jscoverage), "Should not instrument b/bar.coffee"

    it "should exclude directories when dynamically instrumenting code", ->

        coffeeCoverage.register(
            path: "relative"
            basePath: path.resolve __dirname, '../testFixtures/testWithExcludes'
            exclude: ["b"]
        )

        require '../testFixtures/testWithExcludes/a/foo.coffee'
        require '../testFixtures/testWithExcludes/b/bar.coffee'

        assert _$jscoverage?, "Code should have been instrumented"
        assert ('a/foo.coffee' of _$jscoverage), "Should instrument a/foo.coffee"
        assert !('b/bar.coffee' of _$jscoverage), "Should not instrument b/bar.coffee"
