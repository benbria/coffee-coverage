fs = require 'fs'
path = require 'path'
path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

# Returns true if `str` starts with `prefix`
exports.startsWith = (str, prefix) ->
    return str[..(prefix.length-1)] == prefix

# Returns true if `str` ends with `suffix`
exports.endsWith = (str, suffix) ->
    return str[-(suffix.length) ..] == suffix

# Shallow copy all properties of src to dest, but only if those properties don't exist on dest.
exports.defaults = (dest, src) ->
    if not dest
        dest = {}

    for key, val of src
        if not (key of dest)
            dest[key] = val

    return dest

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
        else if exports.startsWith pathElement, "."
            answer += pathElement[0..1]
        else
            answer += pathElement[0]
        answer += path.sep

    answer += filename

    if needTrailingSlash
        answer += path.sep

    return answer

