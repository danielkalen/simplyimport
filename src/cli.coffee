#!/usr/bin/env coffee
yargs = require 'yargs'
	.usage(require './cliUsage')
	.options(require './cliOptions')
	.help('h')
	.wrap(require('yargs').terminalWidth())
	.version(()-> require('../package.json').version)
args = yargs.argv
SimplyImport = require './simplyimport'
regEx = require './regex'
path = require 'path'
fs = require 'fs'


inputPath = args.i or args.input or args._[0]
outputPath = args.o or args.output or args._[1]
help = args.h or args.help
outputIsFile = regEx.fileExt.test(outputPath)
passedOptions = 
	'uglify': args.u or args.uglify
	'preserve': args.p or args.preserve
	'silent': args.s or args.silent
	'track': args.t or args.track
	'recursive': args.r or args.recursive
	'conditions': args.c or args.conditions or []

exitWithHelpMessage = ()->
	process.stdout.write(yargs.help());
	process.exit(0)

exitWithHelpMessage() if help






## ==========================================================================
## Logic invocation
## ========================================================================== 
# ==== Output Path dir to file normalization =================================================================================
if outputPath and not outputIsFile
	if inputPath
		extension = path.extname(inputPath)
		outputPath += '/' if outputPath.slice(-1)[0] isnt '/'
		outputPath += path.basename(inputPath, extension)+'.compiled'+extension
	else
		throw 'Output file path (not just a directory path) must be provided if the input is from stdin'
	




writeResult = (processedContent)->
	if outputPath
		outputPath = path.normalize(outputPath)
		fs.writeFile(outputPath, processedContent)
	else
		process.stdout.write(processedContent)




if inputPath? # File i/o
	writeResult SimplyImport(inputPath, passedOptions)

else # Stream i/o
	input = ''
	process.stdin.on 'data', (data)-> input += data.toString()
	process.stdin.on 'end', ()-> writeResult SimplyImport(input, passedOptions, isStream:true)

	setTimeout ()->
		exitWithHelpMessage() if not input
	, 250
	
		




