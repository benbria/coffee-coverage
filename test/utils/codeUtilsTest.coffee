{expect}  = require 'chai'
codeUtils = require '../../src/utils/codeUtils'

describe 'codeUtils', ->
    describe 'compareLocations()', ->
        it 'should correctly figure out which location comes first', ->
            expect(codeUtils.compareLocations({line: 0, column: 0}, {line: 1, column: 0})).to.equal -1
            expect(codeUtils.compareLocations({line: 2, column: 0}, {line: 1, column: 0})).to.equal 1
            expect(codeUtils.compareLocations({line: 1, column: 0}, {line: 1, column: 0})).to.equal 0
            expect(codeUtils.compareLocations({line: 0, column: 10}, {line: 0, column: 20})).to.equal -1
            expect(codeUtils.compareLocations({line: 0, column: 20}, {line: 0, column: 10})).to.equal 1
            expect(codeUtils.compareLocations({line: 1, column: 10}, {line: 0, column: 20})).to.equal 1
            expect(codeUtils.compareLocations({line: 0, column: 20}, {line: 1, column: 10})).to.equal -1

    describe 'minLocation()', ->
        it "should find the minimum location", ->
            expect(
                codeUtils.minLocation([{line: 1, column: 10}, {line: 1, column: 20}])
            ).to.eql {line:1, column: 10}

        it "should find the minimum location when order is reversed", ->
            expect(
                codeUtils.minLocation([{line: 1, column: 20}, {line: 1, column: 10}])
            ).to.eql {line:1, column: 10}

        it "should find the minimum location when on different lines", ->
            expect(
                codeUtils.minLocation([{line: 1, column: 20}, {line: 2, column: 10}])
            ).to.eql {line:1, column: 20}

            expect(
                codeUtils.minLocation([{line: 1, column: 10}, {line: 2, column: 20}])
            ).to.eql {line:1, column: 10}

        it "should return null when given no locations", ->
            expect(
                codeUtils.minLocation([])
            ).to.eql null

