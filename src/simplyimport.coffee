applyIncludesPolyfill()
fs = require('fs')
path = require('path')
uglify = require('uglify-js')
extend = require('object-extend')
extRegEx = /.+\.(js|coffee)$/i
importRegEx = /(\s*)?(?:\/\/|\#)\s*?@import\s*(?:\{(.+)\})?\s*(.+)/ig
importHistory = []

startReplacement = (input, output, passedOptions)->
	defaultOptions = 
		inputType: 'stream'
		outputIsFile: false
		uglify: false
		recursive: true
		stdout: false
		preserve: false
		conditions: []
		cwd: process.cwd(),
		coffee: false
	options = extend(defaultOptions, passedOptions)

	importHistory = [] # Fresh Start
	
	if !output? and !options.stdout then inputIsFromModule = true
	

	if options.inputType is 'stream'
		inputContent = input
		dirContext = options.cwd
		isCoffeeFile = options.coffee

	else if options.inputType is 'path'
		input = path.normalize(input)
		output = path.normalize(output)
		fileExt = input.match(extRegEx)[1]
		isCoffeeFile = fileExt.toLowerCase() is 'coffee'
		inputContent = getFileContents(input, isCoffeeFile, inputIsFromModule)
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
					replacedContent = replacedContent.split('\n').map((line)-> return spacing+line).join('\n')
				replacedContent = '\n'+replacedContent

			if isCoffeeFile and !childIsCoffeeFile
				return replacedContent.replace /^(\s*)((?:.|\n)+)/, (entire, spacing='', content)-> return spacing+'`'+content+'`' # Wraps standard javascript code with backtics so coffee script could be properly compiled.
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




















# ==== Array.includes polyfill =================================================================================
`function applyIncludesPolyfill(){
	if (!Array.prototype.includes) {
		Array.prototype.includes = function(searchElement /*, fromIndex*/ ) {
			'use strict';
			var O = Object(this),
				len = parseInt(O.length) || 0;
			if (len === 0) return false;
			
			var n = parseInt(arguments[1]) || 0,
				k;
			if (n >= 0) {
			  k = n;
			} else {
			  k = len + n;
			  if (k < 0) {k = 0;}
			}
			var currentElement;
			while (k < len) {
			  currentElement = O[k];
			  if (searchElement === currentElement ||
			     (searchElement !== searchElement && currentElement !== currentElement)) {
			    return true;
			  }
			  k++;
			}
			return false;
		};
	}
}`





module.exports = startReplacement