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
		setTimeout (()-> process.exit(1)), 200

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
	suiteSetup ()-> 
		Promise.all [
			fs.writeAsync temp('basicMain.js'), "var abc = require('./basic.js')\nvar def = require('./exportless')"
			fs.writeAsync temp('basic.js'), "module.exports = 'abc123'"
			fs.writeAsync temp('exportless.js'), "'def456'"
		]

	test "SimplyImport() is an alias for SimplyImport.compile()", ()->
		Promise.resolve()
			.then ()->
				Promise.all [
					SimplyImport(file:temp('basicMain.js'))
					SimplyImport.compile(file:temp('basicMain.js'))
				]
			.then ([bundleA, bundleB])->
				assert.equal bundleA, bundleB


	test "if passed a string instead of options object the string will be considered as the file path", ()->
		Promise.resolve()
			.then ()->
				Promise.all [
					SimplyImport(file:temp('basicMain.js'))
					SimplyImport(temp('basicMain.js'))
				]
			.then ([bundleA, bundleB])->
				assert.equal bundleA, bundleB


	test "if neither options.src and options.file are passed an error will be thrown", ()->
		expect ()-> SimplyImport({})
			.to.throw()


	test "compile command will return a promise by default and a stream if passed a truthy value as 2nd arg", ()->
		promise = SimplyImport(src:'var abc = 123')
		stream = SimplyImport(src:'var abc = 123', true)
		assert.instanceOf promise, Promise, 'is instance of Promise'
		assert.instanceOf stream, (require 'stream'), 'is instance of Stream'

		promiseResult = ''
		streamResult = ''
		promise.then (result)-> promiseResult = result
		stream.on 'data', (chunk)-> streamResult += chunk.toString()
		
		Promise.resolve()
			.then ()-> require('p-wait-for') (-> promiseResult and streamResult and true or false), 2
			.timeout(200)
			.then ()-> assert.equal promiseResult, streamResult


	test "inline imports will be wrapped in paranthesis when there is only one node in the body and when it isn't a variable declaration", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import './a';
						import './b';
						importInline './c';
						import './d';
						import './e';
					"""
					'a.js': """
						abc = 'abc'
					"""
					'b.js': """
						abc = 'abc'; ABC = 'ABC'
					"""
					'c.js': """
						var def = 'def'
					"""
					'd.js': """
						DEF = 'DEF'
					"""
					'e.js': """
						function eee(){return 'eee'}
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc'
				assert.equal context.ABC, 'ABC'
				assert.equal context.def, 'def'
				assert.equal context.DEF, 'DEF'
				assert.equal context.ABC, 'ABC'
				# assert.typeOf context.eee, 'function'
				# assert.equal context.eee(), 'eee'
				assert.notInclude compiled, "(abc = 'abc'; ABC = 'ABC')"
				assert.notInclude compiled, "(var def = 'def')"
				assert.include compiled, "(abc = 'abc')"
				assert.include compiled, "(DEF = 'DEF')"
				assert.include compiled, "(function eee"


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
				assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
				assert.equal context.abc, 'ABC'
				assert.equal context.ABC, 'aBc'
				assert.equal context.def, 'dEf'
				assert.equal context.DEF, 'DeF'
				assert.equal context.ghi, 'ghi'


	test "files without exports won't be considered inline if they are imported more than once", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import 'fileA.js'
						import 'fileB.js'
					"""
					'fileA.js': """
						var abcA = (function(){require('./a')})().toUpperCase()
						var defA = (function(){require('./b')})().toLowerCase()
					"""
					'fileB.js': """
						var abcB = (function(){require('./a')})().toUpperCase()
					"""
					'a.js': """
						return 'aBc'
					"""
					'b.js': """
						return 'dEf'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.include compiled, 'require =', "should have a module loader"
				assert.equal context.abcA, 'ABC'
				assert.equal context.defA, 'def'
				assert.equal context.defB, 'def'














