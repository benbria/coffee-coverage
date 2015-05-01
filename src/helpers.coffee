assert       = require 'assert'
fs           = require 'fs'
path         = require 'path'
coffeeScript = require 'coffee-script'
_            = require 'lodash'
{EXTENSIONS} = require './constants'

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

# Return the relative path for the file from the basePath.  Returns file name
# if the file is not relative to basePath.
exports.getRelativeFilename = (basePath, fileName) ->
    if basePath? and _.startsWith(fileName, basePath)
        fileName = path.relative basePath, fileName
    return fileName

# Return true if we should exclude a file.
#
# `fileName` should be a resolved path (e.g. /users/jwalton/projects/foo/src/blah.coffee)
#
exports.excludeFile = (fileName, options) ->
    basePath = options.basePath
    exclude = options.exclude

    resolvedFileName = path.resolve fileName
    assert resolvedFileName is fileName

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

# Takes the contents of a file and returns an array of lines.
# `source` is a string containing an entire file.
exports.fileToLines = (source) ->
    dataWithFixedLfs = source.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    return dataWithFixedLfs.split("\n")
