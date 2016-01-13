assert       = require 'assert'
fs           = require 'fs'
path         = require 'path'
_            = require 'lodash'
{EXTENSIONS} = require '../constants'
glob         = require 'glob'

exports.stripLeadingDotOrSlash = (pathName) -> pathName.replace(/^\//, "").replace(/^\.\//, "")

# Get details about a file.  Returns a fs.Stats object, or null if the file does not exist.
exports.statFile = statFile = (file) ->
    if !fs.existsSync(file) then return null
    return fs.statSync(file)

# Creates the directory supplied by `dirPath`, creating any intermediate directories as
# required.  For example, `mkdirs('a/b/c')` might create the directory 'a', then 'a/b', then
# 'a/b/c'.
exports.mkdirs = (dirPath, mode) ->
    # Short-circuit if path already exists
    if not statFile dirPath
        pathElements = dirPath.split path.sep

        if _.last(pathElements) is '' then pathElements.pop()

        currentPath = ""
        for pathElement in pathElements
            currentPath += pathElement + path.sep
            stat = statFile currentPath

            if stat and not stat.isDirectory()
                throw new CoverageError("Can't create directory #{currentPath}: file already exists.")

            if not stat
                # Create the directory
                fs.mkdirSync currentPath, mode

        return true

    return false

# Return the relative path for the file from the basePath.  Returns file name
# if the file is not relative to basePath.
exports.getRelativeFilename = (basePath, fileName) ->
    if basePath? and _.startsWith(fileName, basePath)
        fileName = path.relative basePath, fileName
    return fileName

# Given an array of globs, returns an array of files which match any glob.  Returned list will be fully resolved paths.
exports.deglob = (globs, basePath) ->
    cwd = basePath ? process.cwd()
    globOptions = {
        cwd: cwd
        # Set `root` here, because this makes it work the way it did pre-glob.  This is also consistent
        # with the behavior of .npmingore and .gitignore.
        root: cwd
        dot: true
    }

    result = globs.map (pattern) ->
        glob.sync(pattern, globOptions)
        .map (val) ->
            # If someone provides a path like "/test" then glob will resolve it for us, but if someone
            # provides a path like "test" then glob will leave it as a relative path.  Resolve everything
            # to canonical paths here.
            path.resolve cwd, val

    result = _.flatten result
    return _.unique result

# Return true if we should exclude a file.
#
# `fileName` should be a resolved path (e.g. /users/jwalton/projects/foo/src/blah.coffee)
# `options.exclude` should be an array of resolved paths to exclude.
#
exports.excludeFile = (fileName, options) ->
    resolvedFileName = path.resolve fileName
    assert resolvedFileName is fileName
    excluded = fileName in (options.exclude or [])

    # If the file is in a folder which is excluded, then exclude the file.
    if !excluded
        options.exclude.forEach (exclude) ->
            if _.startsWith fileName, "#{exclude}/" then excluded = true

    return excluded

# Takes in a string, and returns a quoted string with any \s and "s in the string escaped to be
# JS friendly.
exports.toQuotedString = (string) ->
        answer = string.replace /\\/g, '\\\\'
        return '"' + (answer.replace /"/g, '\\\"') + '"'
