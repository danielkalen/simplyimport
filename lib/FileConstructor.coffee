fs = require 'fs'
md5 = require 'md5'
path = require 'path'
chalk = require 'chalk'
regEx = require './regex'
deAsync = require 'deasync'
helpers = require './helpers'
browserify = require 'browserify'
consoleLabels = require './consoleLabels'

###*
 * The object created for each file path the program needs to open/import/read.
 * @param {String} input               	File's path or file's contents
 * @param {Object} state	          	(optional) initial state map to indicate if 'isStream', 'isCoffee', and 'context'
 * @param {Object} importHistory	 	(optional) the import history collected so far since the main faile import
###
File = (input, state={}, @importHistory={})->
	@[key] = value for key,value of state
	@trackedImportHistory = {}
	@context = process.cwd()
	@isCoffee ?= false
	@isStream ?= false

	if @isStream
		@content = input
	else
		@filePath = path.normalize(input)
		@fileExt = path.extname(@filePath).toLowerCase().slice(1)
		@context = helpers.getNormalizedDirname(@filePath)
		@isCoffee = @checkIfIsCoffee()
		@content = @getContents()

		if @content is false
			@content = ''
			if not options.silent
				console.warn "#{consoleLabels.warn} Failed to import nonexistent file: #{chalk.dim(helpers.simplifyPath @filePath)}"

	@collectTrackedImports()
	@hash = md5(@content)

	if regEx.commonJS.import.test(@content) or regEx.commonJS.export.test(@content)
		bundle = deAsync browserify(@content, {basedir:path.dirname(@filePath)}).bundle
		contentBuffer = bundle()
		@content = contentBuffer.toString()

	return @




File::getContents = ()->
	return try fs.readFileSync(@filePath).toString() catch then false




File::collectTrackedImports = ()-> if @content
	@content.replace regEx.trackedImport, (entire, hash)=>
		@importHistory[hash] = @trackedImportHistory[hash] = @filePath or 'stdin'



File::checkIfIsCoffee = ()-> if @fileExt then @fileExt is 'coffee' else @isCoffee








module.exports = File