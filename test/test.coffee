global.Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
mocha = require 'mocha'
vm = require 'vm'
assert = require('chai').assert
expect = require('chai').expect
helpers = require './helpers'
# Streamify = require 'streamify-string'
# Browserify = require 'browserify'
# Browserify::bundleAsync = Promise.promisify(Browserify::bundle)
# regEx = require '../lib/constants/regex'
# exec = require('child_process').exec
nodeVersion = parseFloat(process.version[1])
badES6Support = nodeVersion < 6
bin = Path.resolve 'bin'
SimplyImport = require '../'

mocha.Runner::fail = do ()->
	orig = mocha.Runner::fail
	(test, err)->
		err.stack = require('../lib/external/formatError').stack(err.stack)
		orig.call(@, test, err)

sample = ()-> Path.join __dirname,'samples',arguments...
debug = ()-> Path.join __dirname,'debug',arguments...
temp = ()-> Path.join __dirname,'temp',arguments...


processAndRun = (opts, filename='script.js', context={})->
	SimplyImport(opts).then (compiled)->
		Promise.resolve()
			.then ()-> (new vm.Script(compiled, {filename})).runInNewContext(context)
			.then (result)-> {result, compiled, context}
			.catch (err)->
				debugPath = debug(filename)
				err.message += "\nSaved compiled result to '#{debugPath}'"
				fs.writeAsync(debugPath, compiled).timeout(500)
					.catch ()-> err
					.then ()-> throw err
		






suite "SimplyImport", ()->
	suiteTeardown ()-> fs.removeAsync(temp())
	# suiteSetup ()-> 
	# 	fs.dirAsync(temp('output')).then ()->
	# 	Promise.all [
	# 		fs.writeAsync temp('someFile.js'), 'abc123'
	# 		fs.writeAsync temp('someFile2.js'), 'def456'
	# 	]


	test "files without exports will be imported inline", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						var abc = require('./fileA').toUpperCase()
						require('./fileB')
						this.ghi = (import './fileC').toLowerCase()
					"""
					'fileA.js': """
						ABC = 'aBc'
					"""
					'fileB.js': """
						var def = 'dEf'
						this.DEF = 'DeF'
					"""
					'fileC.js': """
						'gHI'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.notIncludes compiled, '_s$m', "module-less bundles shouldn't have a module loader"
				assert.equal context.abc, 'ABC'
				assert.equal context.ABC, 'aBc'
				assert.equal context.def, 'dEf'
				assert.equal context.DEF, 'DeF'
				assert.equal context.ghi, 'ghi'















