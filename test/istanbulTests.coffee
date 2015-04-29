path = require 'path'
{expect} = require 'chai'

coffeeCoverage = require("../src/coffeeCoverage")
Istanbul = require '../src/instrumentors/Istanbul'

{COVERAGE_VAR, log} = require './testConfig'
FILENAME = '/Users/jwalton/foo.coffee'

run = (source) ->
    instrumentor = new Istanbul(FILENAME, {log, coverageVar: COVERAGE_VAR})
    result = coffeeCoverage._runInstrumentor instrumentor, FILENAME, source, {log}
    return {instrumentor, result}

checkStatementsAreCovered = (instrumentor, result, statementCount, filename=FILENAME) ->
    expect(instrumentor.statementMap.length, 'statement count').to.equal statementCount
    [1..statementCount].forEach (id) ->
        expect(result.js, "statement #{id} should be instrumented")
        .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].s[#{id}]++"

# `sizeForBranch` is a hash of branch IDs to branch numbers.  e.g. for a `switch` with three cases,
# you would supply `{1: 3}`
checkBranchesAreCovered = (instrumentor, result, sizeForBranchId, filename=FILENAME) ->
    branchCount = Object.keys(sizeForBranchId).length
    expect(instrumentor.branchMap.length, 'branch count').to.equal branchCount

    Object.keys(sizeForBranchId).forEach (branchId, branchIndex) ->
        expectedLocationCount = sizeForBranchId[branchId]

        expect(instrumentor.branchMap[branchIndex].locations.length).to.equal expectedLocationCount

        [0...expectedLocationCount].forEach (locNumber) ->
            expect(result.js, "branch #{branchId}[#{locNumber}] should be instrumented")
            .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].b[#{branchId}][#{locNumber}]++"

checkFunctionsAreCovered = (instrumentor, result, fnCount, filename=FILENAME) ->
    expect(instrumentor.fnMap.length, "functions found").to.equal fnCount
    [1...fnCount+1].forEach (id) ->
        expect(result.js, "function #{id} should be instrumented")
        .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].f[#{id}]++"

describe "Istanbul tests", ->
    it "should find statements", ->
        {instrumentor, result} = run """
            console.log "Hello world!"
        """

        checkStatementsAreCovered instrumentor, result, 1
        expect(instrumentor.statementMap[0]).to.eql {
            start: {line: 1, column: 0}, end: {line: 1, column: 25}
        }
        checkBranchesAreCovered instrumentor, result, {}
        checkFunctionsAreCovered instrumentor, result, 0

    it "should find if branches", ->
        {instrumentor, result} = run """
            if x
                console.log "Hello world!"
            else
                console.log "Goodbye world!"
        """

        checkStatementsAreCovered instrumentor, result, 3
        # FIXME: Istanbul will put the `end` of the `if` statement on line 4.  It will put the
        # end of a chained if/else if/else statement at the end of the last else.
        expect(instrumentor.statementMap[0], "first statement").to.eql {
            start: {line: 1, column: 0}, end: {line: 2, column: 30}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 29}
        }
        expect(instrumentor.statementMap[2], "third statement").to.eql {
            start: {line: 4, column: 4}, end: {line: 4, column: 31}
        }

        checkBranchesAreCovered instrumentor, result, {1: 2}
        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }

        checkFunctionsAreCovered instrumentor, result, 0

    it "should find if branches with no else", ->
        {instrumentor, result} = run """
            if x
                console.log "Hello world!"
        """

        checkStatementsAreCovered instrumentor, result, 2
        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Wha?  Why do these end on different columns?
            start: {line: 1, column: 0}, end: {line: 2, column: 30}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 29}
        }

        checkBranchesAreCovered instrumentor, result, {1: 2}
        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }

        checkFunctionsAreCovered instrumentor, result, 0

    it "should correctly compile an 'if' which is an expression instead of a statement", ->
        {instrumentor, result} = run 'x = if true then 0 else 1'

        # TODO: Right now this actually instruments the `0` and the `1` as statements.  The
        # generated code looks totally insane, but bizarrely, it actually works.  :P  We might want
        # to explicitly disable this behavior, though...  Have to see if it causes any weird consequences.
        checkStatementsAreCovered instrumentor, result, 3

    it "should correctly compile an 'if' which is a destructuring expression", ->
        {instrumentor, result} = run '[x,y] = if true then [0,1] else [2,3]'

        checkStatementsAreCovered instrumentor, result, 3


    it "should find switch/case branches", ->
        {instrumentor, result} = run """
            switch x
                when 1
                    console.log "a"
                when 2 then console.log "b"
                else
                    console.log "c"
        """

        checkStatementsAreCovered instrumentor, result, 4
        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Should really end on col 22?
            start: {line: 1, column: 0}, end: {line: 6, column: 23}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 3, column: 8}, end: {line: 3, column: 22}
        }
        expect(instrumentor.statementMap[2], "third statement").to.eql {
            start: {line: 4, column: 16}, end: {line: 4, column: 30}
        }
        expect(instrumentor.statementMap[3], "fourth statement").to.eql {
            start: {line: 6, column: 8}, end: {line: 6, column: 22}
        }

        checkBranchesAreCovered instrumentor, result, {1: 3}
        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            type: 'switch'
            locations: [
                {start: {line: 2, column: 4}, end: {line: 3, column: 22}}
                {start: {line: 4, column: 4}, end: {line: 4, column: 30}}
                # TODO: start should really be the start of the `else`.
                {start: {line: 6, column: 8}, end: {line: 6, column: 22}}
            ]
        }

        checkFunctionsAreCovered instrumentor, result, 0

    # TODO: switch with no 'else' case?  Istanbul doesn't instrument this.  Should we?

    it "should find functions", ->
        {instrumentor, result} = run """
            myFunc = ->
                console.log "Hello"
        """

        checkStatementsAreCovered instrumentor, result, 2
        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Should end on 22?
            start: {line: 1, column: 0}, end: {line: 2, column: 23}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 22}
        }

        checkFunctionsAreCovered instrumentor, result, 1
        expect(instrumentor.fnMap[0]).to.eql {
            name: 'myFunc'
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 1, column: 10}}
        }

    it "should use right-most name for funciton with multiple names", ->
        {instrumentor, result} = run """
            x = y = -> console.log "Hello"
        """

        checkFunctionsAreCovered instrumentor, result, 1
        expect(instrumentor.fnMap[0].name).to.equal 'y'


    it "should find functions in a class", ->
        {instrumentor, result} = run """
            class Foo
                constructor: ->
                    @bar = 'Hello World'
        """

        checkStatementsAreCovered instrumentor, result, 3
        expect(instrumentor.statementMap[0], "class statement").to.eql {
            # Should end on column 27?
            start: {line: 1, column: 0}, end: {line: 3, column: 28}
        }
        expect(instrumentor.statementMap[1], "constructor declaration statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 3, column: 28}
        }
        expect(instrumentor.statementMap[2], "constructor body").to.eql {
            start: {line: 3, column: 8}, end: {line: 3, column: 27}
        }

        checkFunctionsAreCovered instrumentor, result, 2
        expect(instrumentor.fnMap[0], "class fn").to.eql {
            name: 'Foo'
            line: 1
            # Should really start at column 0, we're dropping the 'class ' at the start.
            loc: {start: {line: 1, column: 6}, end: {line: 1, column: 8}}
        }
        expect(instrumentor.fnMap[1], "constructor fn").to.eql {
            # TODO: Should this be 'Foo.constructor'?  That would be slick.
            name: 'constructor'
            line: 2
            loc: {start: {line: 2, column: 4}, end: {line: 2, column: 18}}
        }

    it "should find name of anonymous class", ->
        {instrumentor, result} = run """
            X = class
                constructor: ->
                    @bar = 'Hello World'
        """

        checkFunctionsAreCovered instrumentor, result, 2
        expect(instrumentor.fnMap[0], "class fn").to.eql {
            name: '(anonymousClass)' # Should be X?
            line: 1
            # Not sure these column counts are at all correct, but good enough...
            loc: {start: {line: 1, column: 4}, end: {line: 1, column: 4}}
        }

# TODO:
# * `foo = bar = -> ...`
# * `Foo = class Bar ...`