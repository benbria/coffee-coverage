# Takes the contents of a file and returns an array of lines.
# `source` is a string containing an entire file.
exports.fileToLines = (source) ->
    dataWithFixedLfs = source.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    return dataWithFixedLfs.split("\n")

# Where `a` and `b` are `{line, column}` objects, return -1 if a < b, 0 if a == b, 1 is a > b.
exports.compareLocations = (a, b) ->
    if a.line < b.line then return -1
    else if a.line > b.line then return 1
    else if a.column < b.column then return -1
    else if a.column > b.column then return 1
    else return 0

# Given an array of `{line, column}` objects, returns the one that occurs earliest in the document.
exports.minLocation = (locations) ->
    if !locations or locations.length is 0 then return null

    min = locations[0]
    locations.forEach (loc) ->
        if exports.compareLocations(loc, min) < 0 then min = loc
    return min

# Given a coffee-script source string, returns the string with all single line comments representing
# pragmas replaced into herecomments, so that they will be preserved when building the AST.
exports.pragmaToHereComment = (source) ->
    if !source or source.length is 0 then return ''

    result = []
    re = /^(\s*)#\s*(!pragma.+|istanbul\s+ignore.+)\s*$/

    for line in source.split '\n'
 
        match = re.exec(line)

        if match

            result.push match[1] + '### ' + match[2] + ' ###'

        else

            result.push line

    return result.join '\n'

