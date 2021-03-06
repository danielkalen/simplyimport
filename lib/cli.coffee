process.title = 'simplyimport'

yargs = require 'yargs'
	.usage(require './cliUsage')
	.options(require './cliOptions')
	.help('h')
	.wrap(require('yargs').terminalWidth())
	.version(()-> require('../package.json').version)
args = yargs.argv
SimplyImport = require './simplyimport'
helpers = require './cliHelpers'
path = require 'path'
fs = require 'fs-extra'


inputPath = args.i or args.input or args._[0]
outputPath = args.o or args.output or args._[1]
help = args.h or args.help
outputIsFile = try fs.statSync(outputPath).isFile()
passedOptions = 
	'transform': helpers.normalizeTransformOpts args.t or args.transform
	'globalTransform': helpers.normalizeTransformOpts args.g or args.globalTransform
	'preserve': args.p or args.preserve
	'recursive': args.r or args.recursive
	'conditions': args.c or args.conditions or []
	'compileCoffeeChildren': args.C or args['compile-coffee-children']
	'includePathComments': args['include-path-comments']



helpers.exitWithHelpMessage() if help


## ==========================================================================
## Attempt to fetch the 'simplyimport' field from the CWD package.json
## ========================================================================== 
try
	packageJson = fs.readFileSync(path.resolve('package.json'), encoding:'utf8')
	passedOptions.fileSpecific = JSON.parse(packageJson).simplyimport;











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
		throw new Error 'Output file path (not just a directory path) must be provided if the input is from stdin'
	




writeResult = (processedContent)->
	if outputPath
		outputPath = path.normalize(outputPath)
		fs.outputFile(outputPath, processedContent)
	else
		process.stdout.write(processedContent)




if inputPath? # File i/o
	SimplyImport(inputPath, passedOptions).then(writeResult)

else # Stream i/o
	input = ''
	process.stdin.on 'data', (data)-> input += data.toString()
	process.stdin.on 'end', ()-> SimplyImport(input, passedOptions, isStream:true).then(writeResult)

	setTimeout ()->
		helpers.exitWithHelpMessage() if not input
	, 250
	
		




