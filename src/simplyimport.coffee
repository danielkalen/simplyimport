#!/usr/bin/env node
applyIncludesPolyfill()
args = require('yargs').argv
fs = require('fs')
path = require('path')
uglify = require('uglify-js')
extend = require('object-extend')

extRegEx = /.+\.(js|coffee)$/i
importRegEx = /(?:\/\/|\#)\s*?@import\s+(.+)/ig
importHistory = []

input = args.i || args.input || args._[0]
output = args.o || args.output || args._[1]
help = args.h || args.help
shouldUglify = args.u || args.uglify
shouldStdout = args.s || args.stdout
notRecursive = args.n || args.notrecursive
outputIsFile = extRegEx.test(output)

if help
	process.stdout.write("
	Usage: simplyimport -i <input> -o <output> -[u|s|n]\n
	\n
    -i, --input   <path>        Path of the file to compile. Can be relative or absolute.\n
    -o, --output  <path>        Path to write the compiled file to. Can be a file, or directory. If omitted the compiled result will be written to stdout.\n
    -s, --stdout                Output the compiled result to stdout. (Occurs by default if no output argument supplied.)\n
    -u, --uglify                Uglify/minify the compiled file.\n
    -n, --notrecursive          Don't attend/follow @import directives inside imported files.\n
    -h, --help                  Print usage info.\n
	")
	process.exit(0)


startReplacement = (input, output, passedOptions)->
	defaultOptions = 
		inputType: 'stream'
		outputIsFile: false
		uglify: false
		recursive: true
		stdout: false
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
	return output = input.replace importRegEx, (match, filePath)->
		filePath = filePath.replace(/['"]/g, '') # Remove quotes form pathname
		resolvedPath = path.normalize(dirContext+'/'+filePath)
		childIsCoffeeFile = resolvedPath.match(extRegEx)? and resolvedPath.match(extRegEx)[1].toLowerCase() is 'coffee'
		importedFileContent = getFileContents(resolvedPath, isCoffeeFile)
		importedHasImports = importRegEx.test(importedFileContent)
		replacedContent = match

		if !importedFileContent then return match # Exits early and returns the original match if file doesn't exist.


		if !importHistory.includes(resolvedPath)
			importHistory.push(resolvedPath)
			
			if importedHasImports
				childDirContext = getNormalizedDirname(resolvedPath)
				replacedContent = applyReplace(importedFileContent, childDirContext, childIsCoffeeFile)
			else
				replacedContent = importedFileContent

		if isCoffeeFile and !childIsCoffeeFile
			return '`'+replacedContent+'`' # Wraps standard javascript code so coffee script could be properly compiled.
		else if !isCoffeeFile and childIsCoffeeFile
			throw new Error('You\'re trying to import a coffeescript file into a JS file, I don\'t think that\'ll work out well :)')
			process.exit(1)
		else
			return replacedContent


getFileContents = (inputPath, isCoffeeFile, inputIsFromModule)->
	if inputIsFromModule
		return inputIsFromModule
	else
		extension = if isCoffeeFile then '.coffee' else '.js'
		inputPathHasExt = extRegEx.test(inputPath)
		inputPath = inputPath+extension if !inputPathHasExt
		if checkIfInputExists(inputPath)
			return fs.readFileSync(inputPath).toString()
		else
			return false


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
	startReplacement(input, output, {inputType:'path', uglify:shouldUglify, shouldStdout:shouldStdout, recursive: !notRecursive, outputIsFile:outputIsFile})

else # Indicates the input is from a stream
	input = ''
	process.stdin.on 'data', (data)->
		input += data.toString()

	process.stdin.on 'end', ()->
		startReplacement(input, output, {inputType:'stream', uglify:shouldUglify, shouldStdout:shouldStdout, recursive: !notRecursive})
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