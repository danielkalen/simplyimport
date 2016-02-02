#!/usr/bin/env node
applyIncludesPolyfill()
options =
	'i':
		alias: 'input'
		demand: true
		describe: 'Path of the file to compile. Can be relative or absolute.'
		type: 'string'

	'o':
		alias: 'output'
		describe: 'Path to write the compiled file to. Can be a file, or directory. If omitted the compiled result will be written to stdout.'
		type: 'string'

	's':
		alias: 'stdout'
		describe: 'Output the compiled result to stdout. (Occurs by default if no output argument supplied.)'
		type: 'boolean'

	'u':
		alias: 'uglify'
		describe: 'Uglify/minify the compiled file.'
		default: false
		type: 'boolean'

	'n':
		alias: 'notrecursive'
		describe: 'Don\'t attend/follow @import directives inside imported files.'
		default: false
		type: 'boolean'

	'p':
		alias: 'preserve'
		describe: '@import directives that have unmatched conditions should be kept in the file.'
		default: false
		type: 'boolean'

	'c':
		alias: 'conditions'
		describe: 'Specify the conditions that @import directives with conditions should match against. Syntax: -c condA condB condC...'
		type: 'array'

fs = require('fs')
path = require('path')
uglify = require('uglify-js')
extend = require('object-extend')
yargs = require('yargs')
		.usage("Usage: simplyimport -i <input> -o <output> -[u|s|n|p|c] \nDirective syntax: // @import {<conditions, separated by commas>} <filepath>")
		.options(options)
		.help('h')
		.alias('h', 'help')
args = yargs.argv

extRegEx = /.+\.(js|coffee)$/i
importRegEx = /(\s*)?(?:\/\/|\#)\s*?@import\s*(?:\{(.+)\})?\s*(.+)/ig
importHistory = []

input = args.i || args.input || args._[0]
output = args.o || args.output || args._[1]
help = args.h || args.help
shouldUglify = args.u || args.uglify
shouldStdout = args.s || args.stdout
shouldPreserve = args.p || args.preserve
notRecursive = args.n || args.notrecursive
conditionsPassed = args.c || args.conditions || []
outputIsFile = extRegEx.test(output)

if help
	process.stdout.write(yargs.help());
	process.exit(0)


startReplacement = (input, output, passedOptions)->
	defaultOptions = 
		inputType: 'stream'
		outputIsFile: false
		uglify: false
		recursive: true
		stdout: false
		preserve: false
		conditions: []
	options = extend(defaultOptions, passedOptions)
	
	if !output? and !options.stdout then inputIsFromModule = true
	

	if options.inputType is 'stream'
		inputContent = input
		dirContext = process.cwd()

	else if options.inputType is 'path'
		input = path.normalize(input)
		output = path.normalize(output)
		fileExt = input.match(extRegEx)[1]
		isCoffeeFile = fileExt.toLowerCase() is 'coffee'
		inputContent = getFileContents(input, isCoffeeFile, inputIsFromModule)
		dirContext = getNormalizedDirname(input)
		# fileName = path.basename(input, '.'+fileExt)

	replacedContent = applyReplace(inputContent, dirContext, isCoffeeFile)
	if shouldUglify then replacedContent = uglify.minify(replacedContent, {fromString: true}).code
	
	
	if inputIsFromModule
		return replacedContent
	else
		if options.outputIsFile
			fs.writeFileSync(output, replacedContent)
		else
			process.stdout.write(replacedContent)



applyReplace = (input, dirContext, isCoffeeFile)->
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
				if !conditionsPassed.includes(condition) then matchedConditions = false



		if matchedConditions
			if !importedFileContent then return match # Exits early and returns the original match if file doesn't exist.
			if !importHistory.includes(resolvedPath)
				importHistory.push(resolvedPath)

				if importedHasImports
					childDirContext = getNormalizedDirname(resolvedPath)
					replacedContent = applyReplace(importedFileContent, childDirContext, childIsCoffeeFile)
				else
					replacedContent = importedFileContent

			if spacing 
				if spacing isnt '\n'
					# spacing = spacing.slice(1) if spacing.slice(0,1) is '\n'
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
			if shouldPreserve then replacedContent else ''


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
		# console.log(error)
		return false





###==========================================================================
   Calling and Initing the script
   ==========================================================================###

# ==== Output Path/Dir Optimization =================================================================================
if !output and input? # Indicates output should be a file and not to stdout
	output = input.replace extRegEx, (entire, endOfPath)-> return '.compiled.'+endOfPath
else if !outputIsFile
	output = output+'/' if output.charAt( output.length-1 ) isnt '/'
	output = output + input.replace extRegEx, (entire, endOfPath)-> return '.compiled.'+endOfPath # Since output is a dir, for the filename we use the input path's filename with an added suffix.
	
# ==== Init Replacement Call =================================================================================
if input?
	startReplacement(input, output, {inputType:'path', recursive:!notRecursive, outputIsFile:outputIsFile, uglify:shouldUglify, shouldStdout:shouldStdout, conditions:conditionsPassed, preserve:shouldPreserve})

else # Indicates the input is from a stream
	input = ''
	process.stdin.on 'data', (data)->
		input += data.toString()

	process.stdin.on 'end', ()->
		startReplacement(input, output, {inputType:'stream', recursive:!notRecursive, uglify:shouldUglify, shouldStdout:shouldStdout, onditions:conditionsPassed, preserve:shouldPreserve})
# ========================================================================== #


















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