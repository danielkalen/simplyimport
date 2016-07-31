if not Array::includes then Array::includes = (subject)-> @indexOf(subject) isnt -1

fs = require('fs')
path = require('path')
uglify = require('uglify-js')
extend = require('object-extend')
importHistory = []
extRegEx = /.+\.(js|coffee)$/i
importRegEx = ///
	(\s*)? # prior whitespace
	(?:\/|\#) # comment declaration
	\s* # whitespace between the comment and the import declaration
	@import # import declaration
	\s* # whitespace after import declaration
	(?:\{(.+)\})? # conditionals
	\s* # whitespace after conditional
	(.+) # filepath
///ig
defaultOptions = 
	inputType: 'stream'
	outputIsFile: false
	uglify: false
	recursive: true
	stdout: false
	preserve: false
	conditions: []
	cwd: process.cwd()
	coffee: false


simplyImport = (input, output, passedOptions)->
	options = extend(defaultOptions, passedOptions)
	importHistory = [] # Fresh Start
	inputIsFromModule = true if !output? and !options.stdout

	
	switch options.inputType
		when 'stream'
			inputContent = input
			dirContext = options.cwd
			isCoffeeFile = options.coffee

		when 'path'
			input = path.normalize(input)
			output = path.normalize(output)
			fileExt = input.match(extRegEx)[1]
			isCoffeeFile = fileExt.toLowerCase() is 'coffee'
			inputContent = getFileContents(input, isCoffeeFile)
			dirContext = getNormalizedDirname(input)
			# fileName = path.basename(input, '.'+fileExt)

	replacedContent = applyReplace(inputContent, dirContext, isCoffeeFile, options)
	if options.uglify then replacedContent = uglify.minify(replacedContent, {fromString: true}).code
	
	
	if inputIsFromModule
		return replacedContent
	else
		if options.outputIsFile
			fs.writeFileSync(output, replacedContent)
		else
			process.stdout.write(replacedContent)



applyReplace = (input, dirContext, isCoffeeFile, options)->
	return output = input.replace importRegEx, (match, spacing, conditions, filePath)->
		filePath = filePath.replace(/['"]/g, '') # Remove quotes form pathname
		resolvedPath = path.normalize(dirContext+'/'+filePath)
		childIsCoffeeFile = resolvedPath.match(extRegEx)? and resolvedPath.match(extRegEx)[1].toLowerCase() is 'coffee'
		importedFileContent = getFileContents(resolvedPath, isCoffeeFile)
		importedHasImports = importRegEx.test(importedFileContent)
		replacedContent = match
		matchedConditions = true
		
		if conditions
			conditions = conditions.split(/,\s?/)
			
			for condition in conditions
				if !options.conditions.includes(condition) then matchedConditions = false



		if matchedConditions
			if !importedFileContent then return match # Exits early and returns the original match if file doesn't exist.
			if !importHistory.includes(resolvedPath)
				importHistory.push(resolvedPath)

				if importedHasImports
					childDirContext = getNormalizedDirname(resolvedPath)
					replacedContent = applyReplace(importedFileContent, childDirContext, childIsCoffeeFile, options)
				else
					replacedContent = importedFileContent

			if spacing 
				if spacing isnt '\n'
					spacing = spacing.replace /^\n*/, ''
					replacedContent = replacedContent.split('\n').map((line)-> spacing+line).join('\n')
				replacedContent = '\n'+replacedContent


			# ==== Returning =================================================================================
			if isCoffeeFile and !childIsCoffeeFile
				return replacedContent.replace /^(\s*)((?:.|\n)+)/, # Wraps standard javascript code with backtics so coffee script could be properly compiled.
					(entire, spacing='', content)->
						escapedContent = content.replace /`/g, ()-> '\\`'
						return spacing+'`'+escapedContent+'`'
			
			else if !isCoffeeFile and childIsCoffeeFile
				throw new Error('You\'re trying to import a coffeescript file into a JS file, I don\'t think that\'ll work out well :)')
				process.exit(1)
			
			else return replacedContent
		

		else 
			if options.preserve then replacedContent else ''




getFileContents = (inputPath, isCoffeeFile, inputIsFromModule)->
	if inputIsFromModule
		return inputIsFromModule
	else
		extension = if isCoffeeFile then '.coffee' else '.js'
		inputPathHasExt = extRegEx.test(inputPath)
		inputPath = inputPath+extension if !inputPathHasExt
		if checkIfInputExists(inputPath)
			return fs.readFileSync(inputPath).toString()
		else return false



getNormalizedDirname = (inputPath)-> 
	return path.normalize( path.dirname( path.resolve(inputPath) ) )



checkIfInputExists = (inputPath)->
	try
		if fs.statSync(inputPath).isFile() then return true else return false
	catch error
		return false



























module.exports = simplyImport