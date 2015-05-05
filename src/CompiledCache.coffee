fs   = require 'fs'
path = require 'path'
_    = require 'lodash'

{EXTENSIONS} = require './constants'
{mkdirs, getRelativeFilename} = require './utils/helpers'

module.exports = class CompiledCache
    constructor: (@basePath, @cacheDir, @ext='_covered') ->

    _getCacheFileName: (fileName, options={}) ->
        newExt = options.ext ? @ext
        relativeFile = getRelativeFilename @basePath, fileName
        cacheFile = path.resolve @cacheDir, relativeFile
        cacheFile += newExt
        return cacheFile

    get: (fileName, compileFn=null) ->
        return compileFn?() if !@cacheDir

        cacheFileName = @_getCacheFileName(fileName)
        answer = null

        if fs.existsSync(cacheFileName)
            fileStat = fs.statSync fileName
            cacheStat = fs.statSync cacheFileName

            if cacheStat.ctime > fileStat.mtime
                answer = fs.readFileSync cacheFileName, {encoding: 'utf8'}

        if !answer? and compileFn?
            answer = compileFn()
            @put fileName, answer

        return answer

    put: (fileName, contents, options={}) ->
        return if !@cacheDir or !contents

        cacheFileName = @_getCacheFileName(fileName, options)
        cacheDir = path.dirname cacheFileName
        mkdirs cacheDir
        fs.writeFileSync cacheFileName, contents, {encoding: 'utf8'}
