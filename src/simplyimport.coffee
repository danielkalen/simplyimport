if not Array::includes then Array::includes = (subject)-> @indexOf(subject) isnt -1

fs = require 'fs-extra'
path = require 'path'
isValidPath = require 'is-valid-path'
uglify = require 'uglify-js'
extend = require 'object-extend'
regEx = require './regex'

importHistory = []

defaultOptions = 
	'inputType': 'stream'
	'outputType': 'stream'
	'uglify': false
	'recursive': true
	'preserve': false
	'conditions': []
	'cwd': process.cwd()
	'coffee': false







beginImport = (input, output, options)->
	@options = extend(defaultOptions, options)
	importHistory.length = 0 # Fresh Start

	if @options.inputType is 'stream' and isValidPath(input)
		@options.inputType = 'path'

	switch @options.inputType
		when 'stream'
			inputContent = input
			dirContext = @options.cwd
			isCoffeeFile = @options.coffee

		when 'path'
			input = path.normalize(input)
			fileExt = input.match(regEx.fileExt)[1]
			isCoffeeFile = fileExt.toLowerCase() is 'coffee'
			inputContent = getFileContents(input, isCoffeeFile)
			dirContext = getNormalizedDirname(input)

	if not inputContent
		console.error 'Import process failed - invalid input'
		return process.exit(1);
	
	replacedContent = applyReplace(inputContent, dirContext, isCoffeeFile)	
	
	return switch @options.outputType
		when 'stream'
			replacedContent
		
		when 'path'
			output = path.normalize(output)
			fs.writeFileSync(output, replacedContent)




applyReplace = (input, dirContext, isCoffeeFile)->
	input.replace regEx.import, (originalContent, priorContent, spacing, conditions, filePath)->
		filePath = filePath.replace(/['"]/g, '') # Remove quotes form pathname
		resolvedPath = path.normalize(dirContext+'/'+filePath)
		childIsCoffeeFile = resolvedPath.match(regEx.fileExt)?[1].toLowerCase() is 'coffee'
		importedFileContent = getFileContents(resolvedPath, isCoffeeFile)
		importedHasImports = regEx.import.test(importedFileContent)
		matchedConditions = true
		
		if conditions
			conditions = conditions.split(/,\s?/)
			
			for condition in conditions
				if !@options.conditions.includes(condition) then matchedConditions = false



		if not matchedConditions
			replacedContent = if @options.preserve then originalContent else ''
		
		else
			if !importedFileContent
				replacedContent = originalContent # Exits early and returns the original match if file doesn't exist.

			else
				if importHistory.includes(resolvedPath)
					replacedContent = originalContent

				else
					importHistory.push(resolvedPath)

					if importedHasImports
						childDirContext = getNormalizedDirname(resolvedPath)
						replacedContent = applyReplace(importedFileContent, childDirContext, childIsCoffeeFile)
					else
						replacedContent = importedFileContent

				if spacing and not priorContent
					if spacing isnt '\n'
						spacing = spacing.replace /^\n*/, ''
						replacedContent = replacedContent.split('\n').map((line)-> spacing+line).join('\n')
					replacedContent = '\n'+replacedContent


			# ==== Returning =================================================================================
				if isCoffeeFile and !childIsCoffeeFile
					replacedContent = replacedContent.replace /^(\s*)((?:.|\n)+)/, # Wraps standard javascript code with backtics so coffee script could be properly compiled.
						(entire, spacing='', content)->
							escapedContent = content.replace /`/g, ()-> '\\`'
							return spacing+'`'+escapedContent+'`'
				
				else if !isCoffeeFile and childIsCoffeeFile
					throw new Error('You\'re trying to import a coffeescript file into a JS file, I don\'t think that\'ll work out well :)')
					process.exit(1)
						

			if @options.uglify
				replacedContent = uglify.minify(replacedContent, {'fromString':true}).code


		if priorContent and replacedContent and replacedContent isnt originalContent
			priorContent += spacing if spacing
			replacedContent = priorContent+replacedContent
		
		return replacedContent




getFileContents = (inputPath, isCoffeeFile)->
	extension = if isCoffeeFile then '.coffee' else '.js'
	inputPathHasExt = regEx.fileExt.test(inputPath)
	inputPath = inputPath+extension if !inputPathHasExt
	if checkIfInputExists(inputPath)
		return fs.readFileSync(inputPath).toString()
	else return false



getNormalizedDirname = (inputPath)-> path.normalize( path.dirname( path.resolve(inputPath) ) )



checkIfInputExists = (inputPath)->
	try
		return fs.statSync(inputPath).isFile()
	catch error
		return false



























module.exports = beginImport