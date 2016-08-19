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


yargs = require 'yargs'
		.usage "Usage: simplyimport -i <input> -o <output> -[u|s|n|p|c] \nDirective syntax: // @import {<conditions, separated by commas>} <filepath>"
		.options options
		.help 'h'
		.alias 'h', 'help'
args = yargs.argv
SimplyImport = require './simplyimport'
regEx = require './regex'


input = args.i or args.input or args._[0]
output = args.o or args.output or args._[1]
help = args.h or args.help
shouldUglify = args.u or args.uglify
shouldStdout = args.s or args.stdout
shouldPreserve = args.p or args.preserve
notRecursive = args.n or args.notrecursive
conditions = args.c or args.conditions or []
outputIsFile = regEx.fileExt.test(output)

if help
	process.stdout.write(yargs.help());
	process.exit(0)






## ==========================================================================
## Logic invocation
## ========================================================================== 

# ==== Output Path/Dir Optimization =================================================================================
if output and input and not outputIsFile
	output += '/' if output.slice(-1)[0] isnt '/'
	output += input.replace regEx.fileExt, (entire, endOfPath)-> return '.compiled.'+endOfPath # Since output is a dir, for the filename we use the input path's filename with an added suffix.
	


performImport = (input, output, inputType)->
	SimplyImport input, output, 
		'inputType': inputType
		'outputType': if output then 'file' else 'stream'
		'recursive': not notRecursive
		'uglify': shouldUglify
		'shouldStdout': shouldStdout
		'conditions': conditions
		'preserve': shouldPreserve


# ==== File i/o =================================================================================
if input?
	processed = performImport(input, output, 'path')

	if not output
		process.stdout.write(processed)


# ==== Stream i/o =================================================================================
else
	input = ''
	process.stdin.on 'data', (data)->
		input += data.toString()

	process.stdin.on 'end', ()->
		processed = performImport(input, output, 'stream')
		
		if not output
			process.stdout.write(processed)




