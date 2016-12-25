Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
replaceAsync = require 'string-replace-async'
md5 = require 'md5'
PATH = require 'path'
chalk = require 'chalk'
regEx = require './regex'
helpers = require './helpers'
browserify = require 'browserify'
consoleLabels = require './consoleLabels'
EMPTYHASH = "d41d8cd98f00b204e9800998ecf8427e"

###*
 * The object created for each file path the program needs to open/import/read.
 * @param {String} input               	File's path or file's contents
 * @param {Object} state	          	(optional) initial state map to indicate if 'isStream', 'isCoffee', and 'context'
 * @param {Object} importHistory	 	(optional) the import history collected so far since the main faile import
###
module.exports = File = (input, @options, @importRefs, {@isMain, @isCoffee, @context}={})->
	@input = input
	@imports = []
	@badImports = []
	@lineRefs = {}
	# if regEx.commonJS.import.test(@content) or regEx.commonJS.export.test(@content)
	# 	bundle = deAsync browserify(@content, {basedir:PATH.dirname(@filePath)}).bundle
	# 	contentBuffer = bundle()
	# 	@content = contentBuffer.toString()

	return @



File::process = ()->
	Promise.bind()
		.then(@getFilePath)
		.then(@resolveContext)
		.then(@checkIfIsCoffee)
		.then(@getContents)
		


File::getContents = ()->
	if @isMain
		return @content = @input
	else
		fs.readFileASync(@filePath, encoding:'utf8')
			.then (content)=>
				@content = content
				@hash = md5(content)
				@contentLines = content.split '\n'
				return content

			# .catch (err)->
			# 	console.error "#{consoleLabels.error} File doesn't exist #{chalk.dim(helpers.simplifyPath @filePath)}"
			# 	process.exit(1)



File::getFilePath = ()->
	if @isMain
		return @context
	
	else if path.extname(@input)
		return @filePath = @input
	
	else
		inputFileName = path.basename(@input)
		parentDir = path.dirname(@input)
		helpers.getDirListing(parentDir).then (parentDirListing)=>
			inputPathMatches = parentDirListing.filter (targetPath)-> targetPath.includes(inputFileName)

			if not inputPathMatches.length
				return @filePath = @input
			else
				exactMatch = inputPathMatches.find (targetPath)-> targetPath is inputFileName
				fileMatch = inputPathMatches.find (targetPath)->
					fileNameSplit = targetPath.replace(inputFileName, '').split('.')
					return !fileNameSplit[0] and fileNameSplit.length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname


				if fileMatch
					return @filePath = PATH.join parentDir, fileMatch
				
				else #if exactMatch
					resolvedPath = PATH.join parentDir, inputFileName
					
					fs.statAsync(resolvedPath).then (pathStats)=>
						if not pathStats.isDirectory()
							return @filePath = resolvedPath
						else
							helpers.getDirListing(resolvedPath).then (targetDirListing)=>
								indexFile = targetDirListing.find (file)-> file.includes('index')

								if indexFile
									return @filePath = PATH.join parentDir, inputFileName, indexFile
								else
									return @filePath = PATH.join parentDir, inputFileName, 'index.js'




File::resolveContext = ()->
	if @isMain
		@context
	else
		@context = helpers.getNormalizedDirname(@filePath)


File::checkIfIsCoffee = ()->
	@isCoffee = PATH.extname(@filePath).toLowerCase().slice(1) is 'coffee' or @isCoffee



File::collectImports = ()->
	replaceAsync @content, regEx.import, (entireLine, priorContent, spacing, conditions='', childPath)=>
		childPath = childPath
			.replace /['"]/g, '' # Remove quotes form pathname
			.replace /\s+$/, '' # Remove whitespace from the end of the string

		if helpers.testForComments(entireLine, @isCoffee)
			return
		
		else if not helpers.testConditions(@options.conditions, conditions)
			@lineRefs[childPath] = @contentLines.indexOf(entireLine)
			@badImports.push(childPath)
		
		else
			childFile = new File childPath, @options, @importRefs, {@isCoffee}
			childFile.process().then ()=>
				@importRefs[childFile.hash] ?= childFile
				@imports.push(childFile.hash)
				
				else if childFile.hash isnt EMPTYHASH
					@importHistory[childFile.hash] = @filePath or 'stdin'
					childContent = childFile.content

					# ==== Child Imports =================================================================================
					if @options.recursive
						childContent = replaceImports(childFile)


					# ==== Spacing =================================================================================
					if priorContent and priorContent.replace(/\s/g, '') is ''
						spacing = priorContent+spacing
						priorContent = ''

					if spacing and not priorContent
						spacedContent = childContent
							.split '\n'
							.map (line)-> spacing+line
							.join '\n'
						
						childContent = spacedContent


					# ==== JS vs. Coffeescript conflicts =================================================================================
					switch
						when @isCoffee and not childFile.isCoffee
							childContent = helpers.formatJsContentForCoffee(childContent)
						

						when childFile.isCoffee and not @isCoffee
							if @options.compileCoffeeChildren
								childContent = coffeeCompiler.compile childContent, 'bare':true
							else
								throw new Error "#{consoleLabels.error} You're attempting to import a Coffee file into a JS file (which will provide a broken file), rerun this import with -C or --compile-coffee-children"


					
					# ==== Minificaiton =================================================================================								
					if @options.uglify
						childContent = uglifier.minify(childContent, {'fromString':true, 'compressor':{'keep_fargs':true, 'unused':false}}).code


		if priorContent and childContent
			childContent = priorContent + spacing + childContent

		return childContent or failedReplacement







