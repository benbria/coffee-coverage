fs           = require 'fs'
path         = require 'path'
coffeeScript = require 'coffee-script'
_            = require 'lodash'
{EXTENSIONS} = require './constants'

path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

exports.stripLeadingDotOrSlash = (pathName) -> pathName.replace(/^\//, "").replace(/^\.\//, "")

# Get details about a file.  Returns a fs.Stats object, or null if the file does not exist.
exports.statFile = statFile = (file) ->
    try
        answer = fs.statSync(file)
    catch err
        if 'code' of err and err.code is 'ENOENT'
            # File does not exist
            answer = null
        else
            # Some other weird error - throw it.
            throw err

    return answer

# Creates the directory supplied by `dirPath`, creating any intermediate directories as
# required.  For example, `mkdirs('a/b/c')` might create the directory 'a', then 'a/b', then
# 'a/b/c'.
exports.mkdirs = (dirPath, mode) ->
    # Short-circuit if path already exists
    if not statFile dirPath
        pathElements = dirPath.split path.sep

        currentPath = ""
        for pathElement in pathElements
            if not pathElement
                # Skip the trailing ""
                continue

            currentPath += pathElement + path.sep
            stat = statFile currentPath

            if stat and not stat.isDirectory()
                throw new CoverageError("Can't create directory #{currentPath}: file already exists.")

            if not stat
                # Create the directory
                fs.mkdirSync currentPath, mode

# Converts a path like "./foo/"
exports.abbreviatedPath = (pathName) ->
    needTrailingSlash = no

    splitPath = pathName.split path.sep

    if splitPath[-1..-1][0] == ''
        needTrailingSlash = yes
        splitPath.pop()

    filename = splitPath.pop()

    answer = ""
    for pathElement in splitPath
        if pathElement.length == 0
            answer += ""
        else if pathElement is ".."
            answer += pathElement
        else if _.startsWith pathElement, "."
            answer += pathElement[0..1]
        else
            answer += pathElement[0]
        answer += path.sep

    answer += filename

    if needTrailingSlash
        answer += path.sep

    return answer

# Return the relative path for the file from the basePath.  Returns file name
# if the file is not relative to basePath.
exports.getRelativeFilename = (basePath, fileName) ->
    relativeFileName = path.resolve fileName
    if basePath? and _.startsWith(relativeFileName, basePath)
        relativeFileName = path.relative basePath, fileName
    return relativeFileName

# Return true if we should exclude a file.
#
# `fileName` should be a resolved path (e.g. /users/jwalton/projects/foo/src/blah.coffee)
#
exports.excludeFile = (fileName, options) ->
    basePath = options.basePath
    exclude = options.exclude

    return if !exclude

    excluded = false
    if basePath
        relativeFilename = exports.getRelativeFilename basePath, fileName
        if relativeFilename == fileName
            # Only instrument files that are inside the project.
            excluded = true

        components = relativeFilename.split path.sep
        for component in components
            if component in exclude
                excluded = true

        if !excluded
            for excludePath in exclude
                # Allow `exlude` paths to start with /s or not.
                if _.startsWith("/#{relativeFilename}", excludePath) or _.startsWith(relativeFilename, excludePath)
                    excluded = true

    if !excluded and (not path.extname(fileName) in Object.keys(EXTENSIONS))
        excluded = true

    if !excluded
        for excludePath in exclude
            if _.startsWith fileName, excludePath
                excluded = true

    return excluded

# Takes in a string, and returns a quoted string with any \s and "s in the string escaped to be
# JS friendly.
exports.toQuotedString = (string) ->
        answer = string.replace /\\/g, '\\\\'
        return '"' + (answer.replace /"/g, '\\\"') + '"'

# Return the type of an AST node.
exports.nodeType = (node) -> node?.constructor?.name or null

# Fix up location data for each instrumented line.  Make these all 0-length,
# so we don't have to rewrite the location data for all the non-generated
# nodes in the tree.
exports.fixLocationData = (instrumentedLine, line) ->
    doIt = (node) ->
        node.locationData =
            first_line: line - 1 # -1 because `line` is 1-based
            first_column: 0
            last_line: line - 1
            last_column: 0
    doIt instrumentedLine
    instrumentedLine.eachChild doIt

insertNodeBeforeNodes = (node, nodeData, newNode) ->
    {parent, childIndex, childAttr} = nodeData

    # childIndex is more of a hint, since nodes can move around.
    if parent[childAttr][childIndex] isnt node
        childIndex = _.indexOf parent[childAttr], node
        if childIndex is -1 then throw new Error "Can't find node in parent"

    parent[childAttr].splice(childIndex, 0, newNode)

# Converts `csSource` into compiled coffee-script, and then inserts the compiled code before
# `node`.  `nodeData` is a `{parent, childIndex, childAttr}` object for `node`.
exports.insertBeforeNode = (node, nodeData, csSource) ->
    compiled = coffeeScript.nodes(csSource)
    exports.fixLocationData compiled, node.locationData.first_line

    # Mark each node as coffee-coverage generated, so we won't try to instrument our instrumented lines.
    setCoffeeCoverageGenerated = (node) ->
        node.coffeeCoverage ?= {}
        node.coffeeCoverage.generated = true
    setCoffeeCoverageGenerated compiled
    compiled.eachChild setCoffeeCoverageGenerated

    insertNodeBeforeNodes node, nodeData, compiled
