conditionalRun = (skip) -> return {
    it: if skip then it.skip else it
    describe: if skip then describe.skip else describe
}

# Some tests alter global variables.  In general, we want to skip these tests if the globals
# already exist (like, if we're altering the Istanbul coverage variable, but it already exists
# because we're running tests inside of Istanbul.)
#
# Usage:
#
#     whenNoGlobal('_$jscoverage').it 'should do stuff', ->
#         # Test goes here...
#
exports.whenNoGlobal = (varName) ->
    return conditionalRun global[varName]?

# Returns an `{it}` object which will only run if `fn` returns true.
exports.when = (fn) ->
    skip = !fn()
    answer = conditionalRun skip
    console.log  "when:", skip, answer
    return answer
