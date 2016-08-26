if not Array::includes then Array::includes = (subject)-> @indexOf(subject) isnt -1
fs = require 'fs-extra'
path = require 'path'
isValidPath = require 'is-valid-path'
uglify = require 'uglify-js'
extend = require 'object-extend'
regEx = require './regex'
helpers = require './helpers'
defaultOptions = require './defaultOptions'
importHistory = []





beginImport = (input, output, options)->
	@options = extend(defaultOptions, options)
	importHistory.length = 0 # Fresh Start

	@options.inputType = 'path' if @options.inputType is 'stream' and isValidPath(input)

	switch @options.inputType
		when 'stream'
			inputContent = input
			dirContext = @options.cwd
			isCoffeeFile = @options.coffee

		when 'path'
			input = path.normalize(input)
			isCoffeeFile = input.match(regEx.fileExt)?[1]?.toLowerCase() is 'coffee'
			inputContent = helpers.getFileContents(input, isCoffeeFile)
			dirContext = helpers.getNormalizedDirname(input)


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
	input
		.split '\n'
		.map((inputLine)-> inputLine.replace regEx.import, (o, priorContent, spacing, conditions, filePath)->
			filePath = filePath.replace(/['"]/g, '') # Remove quotes form pathname
			resolvedPath = path.normalize dirContext+'/'+filePath
			childIsCoffee = helpers.checkIfIsCoffee(resolvedPath)
			importedFileContent = helpers.getFileContents(resolvedPath, isCoffeeFile)
			importedHasImports = regEx.import.test(importedFileContent)
			matchedConditions = true
			
			if conditions
				conditions = conditions.split(/,\s?/)
				
				for condition in conditions
					if !@options.conditions.includes(condition) then matchedConditions = false



			if not matchedConditions
				replacedContent = if @options.preserve then inputLine else ''
			
			else
				if !importedFileContent
					replacedContent = inputLine # Exits early and returns the original match if file doesn't exist.

				else
					if importHistory.includes(resolvedPath)
						replacedContent = inputLine

					else
						importHistory.push(resolvedPath)

						if importedHasImports
							childDirContext = helpers.getNormalizedDirname(resolvedPath)
							replacedContent = applyReplace(importedFileContent, childDirContext, childIsCoffee)
						else
							replacedContent = importedFileContent

					if spacing and not priorContent
						if spacing isnt '\n'
							spacing = spacing.replace /^\n*/, ''
							replacedContent = replacedContent.split('\n').map((line)-> spacing+line).join('\n')
						replacedContent = '\n'+replacedContent


				# ==== Returning =================================================================================
					if isCoffeeFile and !childIsCoffee
						replacedContent = replacedContent.replace /^(\s*)((?:.|\n)+)/, # Wraps standard javascript code with backtics so coffee script could be properly compiled.
							(entire, spacing='', content)->
								escapedContent = content.replace /`/g, ()-> '\\`'
								return spacing+'`'+escapedContent+'`'
					
					else if !isCoffeeFile and childIsCoffee
						throw new Error('You\'re trying to import a coffeescript file into a JS file, I don\'t think that\'ll work out well :)')
						process.exit(1)
							

				if @options.uglify
					replacedContent = uglify.minify(replacedContent, {'fromString':true}).code


			if priorContent and replacedContent and replacedContent isnt inputLine
				priorContent += spacing if spacing
				replacedContent = priorContent+replacedContent
			
			return replacedContent
		
		).join '\n'




























module.exports = beginImport