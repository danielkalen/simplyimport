require('array-includes').shim()
path = require 'path'
chalk = require 'chalk'
extend = require 'extend'
coffeeCompiler = require 'coffee-script'
uglifier = require 'uglify-js'
helpers = require './helpers'
regEx = require './regex'
defaultOptions = require './defaultOptions'
consoleLabels = require './consoleLabels'
File = require './FileConstructor'
EMPTYHASH = "d41d8cd98f00b204e9800998ecf8427e"






SimplyImport = (input, passedOptions, passedState)->
	@options = extend({}, defaultOptions, passedOptions)
	subjectFile = new File(input, passedState)

	if not subjectFile.content
		throw new Error "#{consoleLabels.error} Import process failed - invalid input #{chalk.underline.magenta(subjectFile.filePath)}"
	else
		processedContent = replaceImports(subjectFile)

		if @options.track
			trackingInfo = (hash for hash of subjectFile.importHistory)
				.filter (hash)-> not subjectFile.trackedImportHistory[hash]
				.map (hash)-> helpers.commentOut "SimplyImported -#{hash}-", subjectFile
				.join '\n'
			
			processedContent = "#{trackingInfo}\n#{processedContent}"

		return processedContent
	



SimplyImport.scanImports = (filePath, pathOnly, pathIsContent)->
	dicoveredImports = []
	if pathIsContent
		fileContent = filePath
	else
		subjectFile = new File(filePath)
		fileContent = subjectFile.content
	
	fileContent
		.split '\n'
		.forEach (line)->
			line.replace regEx.import, (entireLine, priorContent, spacing, conditions, childPath)->
				childPath = childPath.replace /['"]/g, ''
				if pathOnly
					dicoveredImports.push childPath
				else
					dicoveredImports.push {entireLine, priorContent, spacing, conditions, childPath}

	return dicoveredImports





replaceImports = (subjectFile)->
	subjectFile.content
		.split '\n'
		.map((originalLine)-> originalLine.replace regEx.import, (entireLine, priorContent, spacing, conditions='', childPath)->
			return originalLine if helpers.testForComments(originalLine, subjectFile)
			failedReplacement = if @options.preserve then helpers.commentOut(originalLine, subjectFile, true) else ''
			
			if helpers.testConditions(@options.conditions, conditions)
				childPath = helpers.normalizeFilePath(childPath, subjectFile.context)
				childFile = new File childPath, {'isCoffee':subjectFile.isCoffee}, subjectFile.importHistory
				
				if subjectFile.importHistory[childFile.hash]
					unless @options.silent
						importerPath = chalk.dim(helpers.simplifyPath subjectFile.importHistory[childFile.hash])
						childPath = chalk.dim(helpers.simplifyPath childPath)
						console.warn "#{consoleLabels.warn} Duplicate import found #{childPath} - originally imported from #{importerPath}"
				
			
				else if childFile.hash isnt EMPTYHASH
					subjectFile.importHistory[childFile.hash] = subjectFile.filePath or 'stdin'
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
						when subjectFile.isCoffee and not childFile.isCoffee
							childContent = helpers.formatJsContentForCoffee(childContent)
						

						when childFile.isCoffee and not subjectFile.isCoffee
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
		
		).join '\n'




























module.exports = SimplyImport