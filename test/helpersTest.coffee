path                = require 'path'
fs                  = require 'fs'
{expect}            = require 'chai'
sinon               = require 'sinon'
_                   = require 'lodash'

helpers             = require "../src/helpers"
testUtils           = require './utils'

describe 'helpers', ->
    testUtils.when(fs.existsSync '/tmp')
    .describe 'statFile', ->
        it 'should find /tmp', ->
            s = helpers.statFile '/tmp'
            expect(s).to.exist
            expect(s.isDirectory()).to.be.true

        testUtils.when(!fs.existsSync '/tmp/argleblargle')
        .it 'should not find /tmp/argleblargle', ->
            s = helpers.statFile '/tmp/argleblargle'
            expect(s).to.not.exist

    testUtils.when(fs.existsSync '/tmp')
    .describe 'mkdirs', ->
        origCwd = process.cwd()
        folders = ['/tmp/coffeeCoverageTest', '/tmp/coffeeCoverageTest/one', '/tmp/coffeeCoverageTest/one/two']
        nukeFolders = ->
            _.clone(folders).reverse().forEach (folder) ->
                if fs.existsSync folder then fs.rmdirSync folder

        beforeEach ->
            nukeFolders()

        after ->
            nukeFolders()
            process.chdir origCwd

        folders.forEach (folder) ->
            it "should create #{folder}", ->
                expect(helpers.mkdirs(folder)).to.be.true
                expect(fs.existsSync(folder)).to.be.true

            it "should create not create existing folder", ->
                expect(helpers.mkdirs(folder)).to.be.true
                expect(helpers.mkdirs(folder)).to.be.false


        it "should create relative path", ->
            process.chdir '/tmp'
            expect(helpers.mkdirs('coffeeCoverageTest/one/two')).to.be.true
            expect(fs.existsSync('/tmp/coffeeCoverageTest/one/two')).to.be.true




