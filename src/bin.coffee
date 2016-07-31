#!/usr/bin/env coffee
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


startReplacement = require('../simplyimport.js')
yargs = require('yargs')
		.usage("Usage: simplyimport -i <input> -o <output> -[u|s|n|p|c] \nDirective syntax: // @import {<conditions, separated by commas>} <filepath>")
		.options(options)
		.help('h')
		.alias('h', 'help')
args = yargs.argv
extRegEx = /.+\.(js|coffee)$/i


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



