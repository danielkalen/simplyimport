fs = require 'fs'
md5 = require 'md5'
path = require 'path'
chalk = require 'chalk'
regEx = require './regex'
helpers = require './helpers'
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
		@fileExt = @filePath.match(regEx.fileExt)?[1].toLowerCase()
		@context = helpers.getNormalizedDirname(@filePath)
		@isCoffee = @checkIfIsCoffee()
		@content = @getContents()

		if not @content and not options.silent
			console.warn "#{consoleLabels.warn} Failed to import nonexistent file: #{chalk.dim(helpers.simplifyPath @filePath)}"

	@collectTrackedImports()
	@hash = md5(@content)
	return @




File::getContents = ()->
	if @fileExt
		return try fs.readFileSync(@filePath).toString() catch then ''

	else if @isCoffee
		pathsToTry = ["#{@filePath}.coffee", "#{@filePath}.js"]
	else
		pathsToTry = ["#{@filePath}.js", "#{@filePath}.coffee"]


	content = ''
	try
		try
			content = fs.readFileSync(pathsToTry[0]).toString()
			succeededPath = 0
		catch
			content = fs.readFileSync(pathsToTry[1]).toString()
			succeededPath = 1

	
	if succeededPath?
		@isCoffee = pathsToTry[succeededPath].includes '.coffee'

	return content





File::collectTrackedImports = ()-> if @content
	@content.replace regEx.trackedImport, (entire, hash)=>
		@importHistory[hash] = @trackedImportHistory[hash] = @filePath or 'stdin'



File::checkIfIsCoffee = ()-> if @fileExt then @fileExt is 'coffee' else @isCoffee








module.exports = File