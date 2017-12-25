Path = require 'path'
fs = require 'fs-jetpack'
vm = require 'vm'
SimplyImport = require '../../'
nodeVersion = parseFloat(process.version.slice(1))
badES6Support = nodeVersion < 6.2
TEST = Path.resolve __dirname,'..'
{assert, expect} = require 'chai'

sample = ()-> Path.join TEST,'samples',arguments...
debug = ()-> Path.join TEST,'debug',arguments...
temp = ()-> Path.join TEST,'temp',arguments...
tmp = ()-> Path.join require('../../lib/helpers/temp')(),arguments...

emptyTemp = ()-> fs.dirAsync temp(), empty:true

runCompiled = (filename, compiled, context)->
	script = if badES6Support then require('traceur').compile(compiled, script:true) else compiled
	if script.includes('$traceurRuntime')
		runtime = fs.read(Path.resolve 'node_modules','traceur','bin','traceur-runtime.js')
		script = "#{runtime}\n\n#{script}"
	(new vm.Script(script, {filename})).runInNewContext(context)

processAndRun = (opts, filename='script.js', context={})->
	context.global ?= context
	SimplyImport(opts).then (compiled)->
		debugPath = debug(filename)
		writeToDisc = ()-> fs.writeAsync(debugPath, compiled).timeout(500)
		run = ()-> runCompiled(debugPath, compiled, context)
		
		Promise.resolve()
			.then run
			.then (result)-> {result, compiled, context, writeToDisc, run}
			.catch (err)->
				err.message += "\nSaved compiled result to '#{debugPath}'"
				writeToDisc()
					.catch ()-> err
					.then ()-> throw err
		

exports.SimplyImport = SimplyImport
exports.badES6Support = badES6Support
exports.nodeVersion = nodeVersion
exports.assert = assert
exports.expect = expect
exports.sample = sample
exports.debug = debug
exports.temp = temp
exports.tmp = tmp
exports.emptyTemp = emptyTemp
exports.runCompiled = runCompiled
exports.processAndRun = processAndRun
exports.lib = require './createLib'
exports.intercept = require './intercept'
exports.spacerTransform = require './spacerTransform'
exports.lowercaseTransform = require './lowercaseTransform'
exports.uppercaseTransform = require './uppercaseTransform'





