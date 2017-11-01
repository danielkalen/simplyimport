global.Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
mocha = require 'mocha'
vm = require 'vm'
stringPos = require 'string-pos'
assert = require('chai').assert
expect = require('chai').expect
TarGZ = require('tar.gz')()
helpers = require './helpers'
nodeVersion = parseFloat(process.version.slice(1))
badES6Support = nodeVersion < 6.2
bin = Path.resolve 'bin'
SimplyImport = require '../'
Browserify = Streamify = null

# require('../lib/defaults').sourceMap = false

if nodeVersion < 5.1
	Object.defineProperty Buffer,'from', value: (arg)-> new Buffer(arg)

mocha.Runner::fail = do ()->
	orig = mocha.Runner::fail
	(test, err)->
		err.stack = require('../lib/external/formatError').stack(err.stack)
		# err = require('../lib/external/formatError')(err)
		orig.call(@, test, err)
		setTimeout (()-> process.exit(1)), 200 unless process.env.CI

sample = ()-> Path.join __dirname,'samples',arguments...
debug = ()-> Path.join __dirname,'debug',arguments...
temp = ()-> Path.join __dirname,'temp',arguments...

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
		run = ()-> runCompiled(filename, compiled, context)
		
		Promise.resolve()
			.then run
			.then (result)-> {result, compiled, context, writeToDisc, run}
			.catch (err)->
				err.message += "\nSaved compiled result to '#{debugPath}'"
				writeToDisc()
					.catch ()-> err
					.then ()-> throw err
		





suite "SimplyImport", ()->
	suiteTeardown ()-> fs.removeAsync(temp())
	suiteSetup ()->
		Promise.all [
			emptyTemp()
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
			.timeout(2000)
			.then ()-> assert.equal promiseResult, streamResult


	test "inline imports will be wrapped in paranthesis when the import statement is part of a member expression", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						this.a = require('./a');
						this.a2 = require('./a2').toUpperCase();
						this.a3 = (require('./a3')).toUpperCase();
						this.b = import './b';
						importInline './c';
						this.d = importInline './d'.toLowerCase();
						require('./e');
						this.f = require('./f')();
						this.f2 = import './f2'();
					"""
					'a.js': """
						abc = 'abc'
					"""
					'a2.js': """
						abc = 'abc'
					"""
					'a3.js': """
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
					'f.js': """
						function fff(){return 'fff'}
					"""
					'f2.js': """
						function fff(){return 'fff'}
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc'
				assert.equal context.ABC, 'ABC'
				assert.equal context.def, 'def'
				assert.equal context.DEF, 'DEF'
				assert.equal context.ABC, 'ABC'
				assert.typeOf context.eee, 'function'
				assert.equal context.eee(), 'eee'
				assert.typeOf context.fff, 'undefined'
				assert.equal context.a, 'abc'
				assert.equal context.a2, 'ABC'
				assert.equal context.a3, 'ABC'
				assert.equal context.b, 'abc'
				assert.equal context.d, 'def'
				assert.equal context.f, 'fff'
				assert.equal context.f2, 'fff'
				assert.equal compiled, """
					this.a = abc = 'abc';
					this.a2 = (abc = 'abc').toUpperCase();
					this.a3 = (abc = 'abc').toUpperCase();
					this.b = abc = 'abc'; ABC = 'ABC';
					var def = 'def';
					this.d = (DEF = 'DEF').toLowerCase();
					function eee(){return 'eee'};
					this.f = (function fff(){return 'fff'})();
					this.f2 = (function fff(){return 'fff'})();
				"""


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
						abcA = (function(){return require('./a')})().toUpperCase()
						defA = (function(){return require('./b')})().toLowerCase()
						ghiA = (function(){return require('./c')})().toUpperCase()
					"""
					'fileB.js': """
						abcB = (function(){return require('./a')})().toUpperCase()
						ghiB = (function(){return require('./c')})().toLowerCase()
					"""
					'a.js': """
						'aBc'
					"""
					'b.js': """
						'dEf'
					"""
					'c.js': """
						ghi = require('./ghi')
						return ghi
					"""
					'ghi.js': """
						module.exports = 'gHi'
					"""

			.then ()-> processAndRun file:temp('main.js'), 'script.js', abcA:1
			.then ({compiled, result, context})->
				assert.include compiled, 'require =', "should have a module loader"
				assert.equal context.abcA, 'ABC'
				assert.equal context.defA, 'def'
				assert.equal context.ghiA, 'GHI'
				assert.equal context.ghiB, 'ghi'
				assert.equal context.ghi, 'gHi'


	test "inline imports turned into module exports will me modified to export their last expression", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import 'a.js' || import 'a.js'
						b = require('b.js') || require('b.js')
						c = import 'c.js' || import 'c.js'
						d = require('d.js') || require('d.js')
						e = import 'e.js' || import 'e.js'
						f = import 'f.js' || import 'f.js'
						g = import 'g.js' || import 'g.js'
						h = import 'h.js' || import 'h.js'
						i = import 'i.js' || import 'i.js'
						j = import 'j.js' || import 'j.js'
						k = import 'k.js' || import 'k.js'
						lll = 'exporter'
						l = import 'l.js' || import 'l.js'
						m = import 'm.js' || import 'm.js'
					"""
					'a.js': """
						abc = 'aAa'
						abc2 = 'AaA'
					"""
					'b.js': """var def = 'bBb'"""
					'c.js': """'cCc'"""
					'd.js': """function(){return 'dDd'}"""
					'e.js': """[1,5,19]"""
					'f.js': """function fff(){return 'fFf'}"""
					'g.js': """
						var ggg = 'gGg', gGg =12;
						function fff(){return 'fFf'}
						if (0) {throw new Error} else {null}
					"""
					'h.js': """
						function fff(){return 'fFf'}
						var hhh = 'hHh', hHh =13;
						if (0) {throw new Error} else {null}
					"""
					'i.js': """
						function fff(){return 'fFf'}
						var iii = 'iIi', iIi =13;
						iiii = 94
						if (0) {throw new Error} else {null}
					"""
					'j.js': """
						jjj = 95
						if (0) {throw new Error} else {null}
						return jjj
					"""
					'k.js': """
						kkk = 123
						return
					"""
					'l.js': """
						lll.toUpperCase()
					"""
					'm.js': """
						if (0) {throw new Error}
					"""

			.then ()-> processAndRun file:temp('main.js'), ignoreSyntaxErrors:true, 'script.js', abcA:1
			.then ({compiled, result, context, writeToDisc})->
				assert.equal context.a, 'AaA', 'last assignment should be exported'
				assert.equal context.abc, 'aAa'
				assert.equal context.abc2, 'AaA'
				assert.equal context.b, 'bBb', 'last declaration should be exported'
				assert.equal context.def, undefined
				assert.equal context.c, 'cCc', 'literals should be exported'
				assert.equal typeof context.d, 'function', 'function expressions should be exported'
				assert.equal context.d(), 'dDd', 'function expressions should be exported'
				assert.equal typeof context.e, 'object', 'object literals should be exported'
				assert.deepEqual context.e, [1,5,19], 'object literals should be exported'
				assert.equal typeof context.f, 'function', 'function declarations should be exported'
				assert.equal context.f(), 'fFf', 'function declarations should be exported'
				assert.equal typeof context.g, 'function', 'last declaration/assignment should be exported'
				assert.equal context.g(), 'fFf'
				assert.equal context.h, 13, 'last declaration/assignment should be exported'
				assert.equal context.i, 94, 'last declaration/assignment should be exported'
				assert.equal context.j, 95, 'if last is return it should be modified to export the return argument'
				assert.equal context.k, undefined, 'if last is empty return then nothing will be exported'
				assert.equal context.l, 'EXPORTER', 'last expression should be exported'
				assert.equal context.lll, 'exporter'
				assert.deepEqual context.m, {}, 'nothing should be exported when nothing is available to be exported'
	

	test "an import path can be extension-less", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './aaa'
						a2 = import './aaa.js'
						b = require('./bbb')
						c = import './ccc'
					"""
					'aaa.js': """
						module.exports = 'abc123'
					"""
					'bbb.nonjs': """
						module.exports = 'def456'
					"""
					'ccc.json': """
						{"a":1, "b":2}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'abc123'
				assert.equal context.a2, 'abc123'
				assert.equal context.b, 'def456'
				assert.deepEqual context.c, {a:1,b:2}
	
	
	test "if the provided import path matches a directory it will be searched for an index file", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = require('./b')
						c = import './c'
					"""
					'a/index.js': """
						module.exports = 'abc123'
					"""
					'b/_index.nonjs': """
						module.exports = 'def456'
					"""
					'c/index.json': """
						{"a":1, "b":2}
					"""
					'c/distraction.json': """
						{"a":2, "b":4}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'abc123'
				assert.equal context.b, 'def456'
				assert.deepEqual context.c, {a:1,b:2}
	
	
	test "extension-less import paths that match a directory and a file will have the file take precedence", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './abc'
						b = require('./def')
						c = importInline './ghi'
					"""
					'abc.js': """
						module.exports = 'ABC123'
					"""
					'abc/index.js': """
						module.exports = 'abc123'
					"""
					'def.nonjs': """
						module.exports = 'DEF456'
					"""
					'def/index.js': """
						module.exports = 'def456'
					"""
					'ghi.other.json': """
						{"a":1, "b":2}
					"""
					'ghi/__index.json': """
						{"a":2, "b":4}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'ABC123'
				assert.equal context.b, 'DEF456'
				assert.deepEqual context.c, {a:2,b:4}
	
	
	test "extension-less import paths that match a directory and a file will have the directory take precedence if the path ends with a slash", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'abc.js': "module.exports = 'abc.js'"
					'abc/index.js': "module.exports = 'abc/index.js'"

			.then ()-> processAndRun file:temp('main.js'), src:"module.exports = import './abc'"
			.then ({result})-> assert.equal result, 'abc.js'

			.then ()-> processAndRun file:temp('main.js'), src:"module.exports = import './abc/'"
			.then ({result})-> assert.equal result, 'abc/index.js'
	
	
	test "extension-less import paths that match a js file and a non-js file will have the js take precedence", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './abc'
						b = require('./abc')
						c = importInline 'abc'
					"""
					'abc.js': """
						module.exports = 'ABC123'
					"""
					'abc.json': """
						{"a":1, "b":2}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'ABC123'
				assert.equal context.b, 'ABC123'
				assert.equal context.c, 'ABC123'
	

	test "import paths not starting with '.' or '/' will be attempted to load from node_modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						abc = import 'abc'
						ghi = importInline 'ghi/file.js'
						def = require("def/nested")
					"""
					'node_modules/abc/index.js': """
						module.exports = 'abc123'
					"""
					'node_modules/def/nested/index.js': """
						module.exports = 'def456'
					"""
					'node_modules/ghi/file.js': """
						theGhi = 'ghi789'
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'def456'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'
	

	test "if a node_modules-compatible path isn't matched in node_modules it will be treated as a local path", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						abc = import 'abc'
						ghi = importInline 'ghi/file'
						def = require("def")
					"""
					'abc.js': """
						module.exports = 'abc123'
					"""
					'node_modules/def/nested/index.js': """
						module.exports = 'DEF456'
					"""
					'def/index.js': """
						module.exports = 'def456'
					"""
					'ghi/file.js': """
						theGhi = 'ghi789'
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'def456'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'


	test "missing files will cause an error to be thrown", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						abc = import 'kkk'
						def = import 'jjj'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.catch (err)-> 'failed as expected'
			.then (result)-> assert.equal result, 'failed as expected'


	test "options.ignoreMissing will surpress missing file errors and will cause them to be replaced with an empty stub", ()->
		Promise.resolve()
			.then ()->
				helpers.intercept.start('stderr')
				helpers.lib
					'main.js': """
						abc = import 'kkk'
						def = import 'jjj'
						ghi = importInline 'ggg'
					"""

			.then ()-> processAndRun file:temp('main.js'), ignoreMissing:true
			.then ({context, compiled})->
				stderr = helpers.intercept.stop()
				assert.deepEqual context.abc, {}
				assert.deepEqual context.def, {}
				assert.deepEqual context.ghi, {}
				assert.include stderr, 'WARN'
				assert.include stderr, 'cannot find'
				assert.include stderr, 'kkk'
				assert.include stderr, 'jjj'
				assert.include stderr, 'ggg'

			.tapCatch (err)-> helpers.intercept.stop()


	test "files matching globs specified in options.ignoreFile shall be replaced via an empty stub", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'entry.js': """
						exports.a = require('./a')
						exports.b = require('./b')
						exports.c = require('./c')
						exports.d = require('./d')
						exports.e = require('./e')
					"""
					'a.js': "module.exports = 'file a.js!'"
					'b.js': "module.exports = 'file b.js!'"
					'c.js': "module.exports = 'file c.js!'"
					'd.js': "module.exports = 'file d.js!'"
					'e.js': "module.exports = 'file e.js!'"

			.then ()-> processAndRun file:temp('entry.js'), ignoreFile:['b.js', '**/temp/d.*']
			.then ({result})->
				assert.deepEqual result.a, 'file a.js!'
				assert.deepEqual result.b, {}
				assert.deepEqual result.c, 'file c.js!'
				assert.deepEqual result.d, {}
				assert.deepEqual result.e, 'file e.js!'


	test "files matching globs specified in options.excludeFile shall be not be included in the bundle", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'entry.js': """
						exports.a = require('./a')
						try {
							exports.b = import './b'
						} catch (e) {
							exports.b = 'excluded';
						}
						exports.c = require('./c')
						try {
							exports.d = require('./d')
						} catch (e) {
							exports.d = 'excluded';
						}
						exports.e = require('./e')
						importInline './f'
						importInline './g'
					"""
					'a.js': "module.exports = 'file a.js!'"
					'b.js': "module.exports = 'file b.js!'"
					'c.js': "module.exports = 'file c.js!'"
					'd.js': "module.exports = 'file d.js!'"
					'e.js': "module.exports = 'file e.js!'"
					'f.js': "inline1 = 'file f.js!'"
					'g.js': "inline2 = 'file g.js!'"

			.then ()-> processAndRun file:temp('entry.js'), excludeFile:['b.js', '**/temp/d.*', '**/f.js']
			.then ({compiled, context, result})->
				assert.deepEqual result.a, 'file a.js!'
				assert.deepEqual result.b, 'excluded'
				assert.deepEqual result.c, 'file c.js!'
				assert.deepEqual result.d, 'excluded'
				assert.deepEqual result.e, 'file e.js!'
				assert.equal context.inline1, undefined
				assert.equal context.inline2, 'file g.js!'
				assert.notInclude compiled, 'inline1'
				assert.notInclude compiled, "import './b'"
				assert.include compiled, "require('./b')"


	test "files external to the importer shall be not be included in the package when options.bundleExternal is false", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = require('./a')
						try {
							exports.b = import 'b'
						} catch (e) {
							exports.b = 'excluded';
						}
						exports.c = require('c')
						try {
							exports.d = require('d')
						} catch (e) {
							exports.d = 'excluded';
						}
					"""
					'a.js': "module.exports = 'file a.js!'"
					'node_modules/b/index.js': "module.exports = 'file b.js!'"
					'node_modules/b/package.json': JSON.stringify main:'index.js'
					'c.js': "module.exports = 'file c.js!'"
					'node_modules/d/index.js': "module.exports = 'file d.js!'"
					'node_modules/d/package.json': JSON.stringify main:'index.js'

			.then ()->
				Promise.all [
					processAndRun file:temp('main.js')
					processAndRun file:temp('main.js'), bundleExternal:false
				]
			.then ([bundleA, bundleB])->
				assert.notEqual bundleA.compiled, bundleB.compiled
				assert.deepEqual bundleA.result.a, 'file a.js!'
				assert.deepEqual bundleA.result.b, 'file b.js!'
				assert.deepEqual bundleA.result.c, 'file c.js!'
				assert.deepEqual bundleA.result.d, 'file d.js!'
				
				assert.deepEqual bundleB.result.a, 'file a.js!'
				assert.deepEqual bundleB.result.b, 'excluded'
				assert.deepEqual bundleB.result.c, 'file c.js!'
				assert.deepEqual bundleB.result.d, 'excluded'


	test "files/modules can be ignored/replaced via package.json's browser field", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'package.json': JSON.stringify
						main: 'main.js'
						browser:
							'./a.js': './a2.js'
							'b': 'b2'
							'c2': './c.js'
							'./node_modules/d/index.js': 'd2'
							'e': false
							'./node_modules/f/name.js': './node_modules/f/name2.js'
					
					'main.js': """
						exports.a = require('./a')
						exports.b = import 'b'
						exports.c = require('c2')
						exports.d = require('d')
						exports.e = require('e')
						exports.f = require('f')
						exports.g = require('g/child')
						exports.h = require('h/child')
						exports.j = require('@private/j/child')
					"""
					'a.js': "module.exports = 'file a.js!'"
					'a2.js': "module.exports = 'file a2.js!'"
					'node_modules/b/index.js': "module.exports = 'file b.js!'"
					'node_modules/b/package.json': JSON.stringify main:'index.js'
					'node_modules/b2/index.js': "module.exports = 'file b2.js!'"
					'node_modules/b2/package.json': JSON.stringify main:'index.js'
					'c.js': "module.exports = 'file c.js!'"
					'node_modules/c2/index.js': "module.exports = 'file c2.js!'"
					'node_modules/c2/package.json': JSON.stringify main:'index.js'
					'node_modules/d/index.js': "module.exports = 'file d.js!'"
					'node_modules/d/package.json': JSON.stringify main:'index.js'
					'node_modules/d2/index.js': "module.exports = 'file d2.js!'"
					'node_modules/d2/package.json': JSON.stringify main:'index.js', browser:'d3'
					'node_modules/d3/index.js': "module.exports = 'file d3.js!'"
					'node_modules/d3/package.json': JSON.stringify main:'index.js'
					'node_modules/e/index.js': "module.exports = 'file e.js!'"
					'node_modules/e/package.json': JSON.stringify main:'index.js'
					'node_modules/f/index.js': "module.exports = 'file '+(import './name')+'!'"
					'node_modules/f/name.js': "module.exports = 'f.js'"
					'node_modules/f/name2.js': "module.exports = 'f2.js'"
					'node_modules/f/package.json': JSON.stringify main:'index.js'
					'node_modules/g/nested/child.js': "module.exports = 'file g/nested/child.js!'"
					'node_modules/g/package.json': JSON.stringify main:'index.js', browser: "./child":"./nested/child"
					'node_modules/h/nested/child.js': "module.exports = 'file h/nested/child.js!'"
					'node_modules/h/package.json': JSON.stringify main:'index.js', browser: "./child":"./nested/child"
					'node_modules/@private/j/nested/child.js': "module.exports = 'file j/nested/child.js!'"
					'node_modules/@private/j/package.json': JSON.stringify main:'index.js', browser: "./child":"./nested/child"

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result})->
				assert.deepEqual result,
					a: 'file a2.js!'
					b: 'file b2.js!'
					c: 'file c.js!'
					d: 'file d3.js!'
					e: {}
					f: 'file f2.js!'
					g: 'file g/nested/child.js!'
					h: 'file h/nested/child.js!'
					j: 'file j/nested/child.js!'
				


	test "options.usePaths will cause modules to be labeled with their relative path instead of a unique inceremental ID", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'nested/main.js': """
						abc = import 'abc'
						ghi = importInline 'ghi/file.js'
						def = require("def/nested")
					"""
					'node_modules/abc/index.js': """
						module.exports = 'abc123'
					"""
					'node_modules/def/nested/index.js': """
						module.exports = 'def456'
					"""
					'node_modules/ghi/file.js': """
						theGhi = 'ghi789'
					"""


			.then ()->
				Promise.all [
					processAndRun file:temp('nested/main.js')
					processAndRun file:temp('nested/main.js'),usePaths:true
				]
			.spread (bundleA, bundleB)->
				assert.notEqual bundleA.compiled, bundleB.compiled
				assert.include bundleA.compiled, '0: function (require'
				assert.notInclude bundleB.compiled, '0: function (require'
				assert.notInclude bundleA.compiled, '"entry.js": function (require'
				assert.include bundleB.compiled, '"entry.js": function (require'
				assert.include bundleB.compiled, '"../node_modules/abc/index.js": function (require'
				assert.include bundleB.compiled, '"../node_modules/def/nested/index.js": function (require'

				context = bundleA.context
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'def456'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'


	test "duplicate import statements within the same file are allowed (both module and inlines)", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = (importInline '2'+importInline '3')*importInline '2'
						exports.a = a
						b = import './abc' + import './def'+require('./def')  +require('./abc')
						exports.b = b
					"""
					'abc.js': 'module.exports = "abc"'
					'def.js': 'module.exports = "def"'
					'2.js': '2'
					'3.js': '3'
			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.a, 10
				assert.equal context.b, 'abcdefdefabc'


	test "es6 exports will be transpiled to commonJS exports", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						import * as aaa from 'a'
						exports.a = aaa
						import * as bbb from 'b'
						exports.b = bbb
						import ccc from 'c'
						exports.c1 = ccc
						import {ccc} from 'c'
						exports.c2 = ccc
						import {abc} from 'd'
						exports.d = abc
						import {abc as ABC, def, ghi as GHI} from 'e'
						exports.e = {ABC:ABC, def:def, GHI:GHI}
						import ggg, * as GGG from 'g'
						exports.g = {ggg:ggg, GGG:GGG}
						import hhh, {hhh as HHH, h2, h1} from 'h'
						exports.h1 = {hhh:hhh, HHH:HHH, h2:h2, h1:h1}
						import hhh, {hhh as HHH, h2, h1} from 'h2'
						exports.h2 = {hhh:hhh, HHH:HHH, h2:h2, h1:h1}
						import * as fff from 'f'
						exports.f = fff
						exports.j = import 'j'
					"""
					'a.js': """
						export default abc = 123
						export function sam(){return 'sammy'}
						export let def = 456
						module.exports.DEF = def
						var jkl = 'jkl'
						var JKL = 'JKL', ghi = 'gHi'
						export {ghi, jkl as JKL}
					"""
					'b.js': """
						export default function abc(a,b){return a+b}
						var abc = 'AbC'
						export {abc as ABC}
						module.exports.AAA = abc
						export const JKL = 'JKl', jkl = 'jKl', def= JKL
					"""
					'c.js': """
						export default function (a,b){return a+b}
						export function ccc(a,b) {return a-b}
					"""
					'd.js': """
						var abc = 'abc'
						export {abc}
						exports.def = 456
						export default abc
					"""
					'e.js': """
						export default abc = 'abc'
						var ABC = 'ABC', def = 'dEf', DEF = 'DEF', ghi = 'ghi', GHI = 'GHI'
						export {abc, def, ghi}
						exports.def = exports.def.toLowerCase()
					"""
					'g.js': """
						export default false || 'maybe'
						export var ABC ='ABC', def = {a:[1,2,3]},

						DEF = ['DEF', {a:[1,2,3]}], ghi = function(){var oi = null;
						let df = 123
						},
						GHI
						=

						'GHI'
						, jkl = GHI
						instanceof Number, JKL = new
						Array	(12,20)
					"""
					'h.js': """
						export default module.exports.notDefault = 'kinsta'
						export let hhh = 'hHh'
						var h1 = 'H2'
						export {h1 as h2}
					"""
					'h2.js': """
						exports.default = module.exports.notDefault = 'kinsta'
						var hhh = exports.hhh = 'hHh'
						var h1 = 'H2'
						exports.h2 = h1
					"""
					'f.js': """
						export * from 'nested/f2'
						export * from 'nested/f3'
						export {a,b,default} from 'nested/f4'
						export var fff = 'fFf'
					"""
					'nested/f2.js': """
						export default function(a,b){return a+b}
						export var abc = 123
						export {jkl as jkl_, JKL} from 'f4'

						module.exports.def = 456
						export var def = 4566, ghi = 789
					"""
					'nested/f3.js': """
						export var GHI = 'GHI'
					"""
					'nested/f4.js': """
						var a = 1, b = 2, jKl = 'jKl'
						export var jkl = 'jkl', JKL='JKL'
						export {a, jKl as default, b}
					"""
					'j.js': """
						export class MyClass {
							constructor(name) {
								this.name = name;
							}
						}
					"""

			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({writeToDisc, compiled, result, run})->
				assert.equal result.a.default, 123
				assert.equal result.a.sam(), 'sammy'
				assert.equal result.a.def, 456
				assert.equal result.a.DEF, 456
				assert.equal result.a.jkl, undefined
				assert.equal result.a.JKL, 'jkl'
				assert.equal result.a.ghi, 'gHi'
				assert.equal result.b.default(2,5), 7
				assert.equal result.b.abc, undefined
				assert.equal result.b.ABC, 'AbC'
				assert.equal result.b.AAA, 'AbC'
				assert.equal result.b.JKL, 'JKl'
				assert.equal result.b.jkl, 'jKl'
				assert.equal result.b.def, 'JKl'
				assert.equal result.c1(9,4), 13
				assert.equal result.c2(9,4), 5
				assert.equal result.d, 'abc'
				assert.equal result.e.ABC, 'abc'
				assert.equal result.e.def, 'def'
				assert.equal result.e.GHI, 'ghi'
				assert.equal result.g.ggg, 'maybe'
				assert.equal result.g.GGG.default, 'maybe'
				assert.equal result.g.GGG.ABC, 'ABC'
				assert.deepEqual result.g.GGG.def, {a:[1,2,3]}
				assert.deepEqual result.g.GGG.DEF, ['DEF', {a:[1,2,3]}]
				assert.equal result.g.GGG.ghi(), null
				assert.equal result.g.GGG.oi, undefined
				assert.equal result.g.GGG.GHI, 'GHI'
				assert.equal result.g.GGG.jkl, false
				assert.deepEqual result.g.GGG.JKL, [12,20]
				assert.equal typeof result.j, 'object'
				assert.equal typeof result.j.MyClass, 'function'
				assert.equal (new result.j.MyClass('random')).name, 'random'
				assert.deepEqual result.h1, {hhh:'kinsta', HHH:'hHh', h2:'H2', h1:undefined}
				assert.deepEqual result.h2, {hhh:'kinsta', HHH:'hHh', h2:'H2', h1:undefined}
				assert.equal result.f.fff, 'fFf'
				assert.equal result.f.abc, 123
				assert.equal result.f.jkl, undefined
				assert.equal result.f.jkl_, 'jkl'
				assert.equal result.f.JKL, 'JKL'
				assert.equal result.f.def, 4566
				assert.equal result.f.ghi, 789
				assert.equal result.f.GHI, 'GHI'
				assert.equal result.f.a, 1
				assert.equal result.f.b, 2
				assert.equal result.f.default, 'jKl'


	test "es6 imports/exports can be placed in nested scopes", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						load = function(){
							import a from './a'
							import * as b from './b'
							import * as c from './c'
							import * as d from './d'
							return {a:a, b:b, c:c, d:d}
						}
						module.exports = load()
					"""
					'a.js': """
						export var abc = 123
						load = function(){
							var def = 456, ghi = 789, jkl = 999;
							export default result = {abc:abc, def:def, ghi:ghi, jkl:jkl}
						}
						load()
					"""
					'b.js': """
						export var abc = 123;
						load = function(){
							var ghi = 789, jkl = 999;
							export let def = 456
							(function(){export {ghi, jkl}})()
						}
						load()
					"""
					'c.js': """
						export var abc = 123
						load = function(){
							var ghi = 789, jkl = 999;
							export let def = 456
							(function(){export {ghi, jkl}})()
						}
					"""
					# 'd.js': """
					# 	export var abc = 123;

					# 	export function load(){
					# 		export let def = 456
					# 		exports.ghi = import './d2'
					# 		exports.jkl = 999
					# 	}
					# """
					'd.coffee': """
						export abc = 123
						export abc2 = 123
						export load = ()->
							exports.def = 456
							exports.ghi = import './d2'
							exports.jkl = 999
					"""
					'd2.js': """
						module.exports = 789;
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, writeToDisc})->
				assert.deepEqual result.a, {abc:123, def:456, ghi:789, jkl:999}
				assert.deepEqual result.b, {abc:123, def:456, ghi:789, jkl:999}
				assert.deepEqual result.c, {abc:123}
				assert.equal result.d.abc, 123
				assert.equal result.d.def, undefined
				assert.equal result.d.ghi, undefined
				assert.equal typeof result.d.load, 'function'
				result.d.load()
				assert.equal result.d.def, 456
				assert.equal result.d.ghi, 789
				assert.equal result.d.jkl, 999


	test "imports/exports should be live", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import * as a from './a'
						import * as b from './b'
						import * as c from './c'
						module.exports = {a:a,b:b,c:c}
					"""
					'a.js': """
						export var abc = 'abc'
						module.exports.def = 'def'
					"""
					'b.js': """
						import * as a from './a'
						module.exports = a
					"""
					'c.js': """
						import * as a from './a'
						module.exports = a
						a.def = a.def.toUpperCase()
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result})->
				assert.deepEqual result.a, {abc:'abc', def:'DEF'}
				assert.equal result.a, result.b
				assert.equal result.a, result.c


	test "commonJS (and commonJS-style) imports importing es6 modules should extract the 'default' property", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a1 = require('./a')
						exports.a2 = import './a'
						import * as a3 from './a'
						exports.a3 = a3
						exports.b1 = require('./b')
						exports.b2 = import './b'
						import * as b3 from './a'
						exports.b3 = b3
						exports.c1 = require('./c')(4,5)
						exports.c2 = (import './c')(7,5)
						exports.c3 = require('./c').inner
					"""
					'a.js': """
						export default abc = 123
						export var def = 456
					"""
					'b.js': """
						exports.default = 123
						exports.def = 456
					"""
					'c.js': """
						export default function abc(a,b){return a*b};
						abc.inner = 'innerValue'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result,writeToDisc})->
				assert.deepEqual result.a1, 123
				assert.deepEqual result.a2, 123
				assert.deepEqual result.a3, {default:123, def:456}
				assert.deepEqual result.b1, 123
				assert.deepEqual result.b2, 123
				assert.deepEqual result.b3, {default:123, def:456}
				assert.deepEqual result.c1, 20
				assert.deepEqual result.c2, 35
				assert.deepEqual result.c3, 'innerValue'


	test "es6 imports importing commonJS modules using the 'default' property should resolve to the entire module", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import a1 from './a'
						exports.a1 = a1
						exports.a2 = require('./a')
						import b1 from './b'
						exports.b1 = b1
						exports.b2 = require('./b')
						import c1 from './c'
						exports.c1 = c1
						exports.c2 = require('./c')
						import d1 from './d'
						exports.d1 = d1
						exports.d2 = require('./d')
						import e1 from './e'
						exports.e1 = e1
						exports.e2 = require('./e')
					"""
					'a.js': """
						module.exports.abc = 123
					"""
					'b.js': """
						module.exports = 456
					"""
					'c.js': """
						export default 789
					"""
					'd.js': """
						exports.default = 111
					"""
					'e.js': """
						exports['default'] = 222
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result,writeToDisc})->
				assert.deepEqual result.a1, abc:123
				assert.deepEqual result.a2, abc:123
				assert.deepEqual result.b1, 456
				assert.deepEqual result.b2, 456
				assert.deepEqual result.c1, 789
				assert.deepEqual result.c2, 789
				assert.deepEqual result.d1, 111
				assert.deepEqual result.d2, 111
				assert.deepEqual result.e1, 222
				assert.deepEqual result.e2, 222


	suite "the module loader should be returned when options.returnLoader is set", ()->
		test "when identifiers are numeric", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							import * as a from './a'
							import * as b from './b'
							import * as c from './c'
							module.exports = {a:a,b:b,c:c}
						"""
						'a.js': """
							export var abc = 'abc'
							module.exports.def = 'def'
						"""
						'b.js': """
							import * as a from './a'
							module.exports = a
						"""
						'c.js': """
							import * as a from './a'
							module.exports = a
							a.def = a.def.toUpperCase()
						"""
				.then ()-> processAndRun file:temp('main.js'), returnLoader:true
				.then ({compiled, result})->
					assert.typeOf result, 'function'
					assert.typeOf result(1), 'object'
					assert.equal result(1).abc, 'abc'
					assert.equal result(1).def, 'def'
					assert.equal result(2).abc, 'abc'
					assert.equal result(2).def, 'def'
					assert.equal result(3).abc, 'abc'
					assert.equal result(3).def, 'DEF'
					assert.equal result(0).a.abc, 'abc'


		test "when identifiers are paths", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							import * as a from 'a'
							import * as b from 'b'
							import * as c from 'c'
							module.exports = {a:a,b:b,c:c}
						"""
						'a.js': """
							export var abc = 'abc'
							module.exports.def = 'def'
						"""
						'b/index.js': """
							import * as a from '../a'
							module.exports = a
						"""
						'node_modules/c/index.js': """
							import * as a from '../../a'
							module.exports = a
							a.def = a.def.toUpperCase()
						"""
						'package.json': '{"main":"main.js"}'
				
				.then ()-> processAndRun file:temp('main.js'), returnLoader:true, usePaths:true
				.then ({compiled, result})->
					assert.typeOf result, 'function'
					assert.typeOf result('a.js'), 'object'
					assert.equal result('a.js').abc, 'abc'
					assert.equal result('a.js').def, 'def'
					assert.equal result('b/index.js').abc, 'abc'
					assert.equal result('b/index.js').def, 'def'
					assert.equal result('node_modules/c/index.js').abc, 'abc'
					assert.equal result('node_modules/c/index.js').def, 'DEF'
					assert.equal result('entry.js').a.abc, 'abc'


	suite "when options.target is set to 'node'", ()->
		test "package.json browser field won't be used", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = require('a.js')
							exports.b = require('b.js')
							exports.c = require('c.js')
							exports.d = require('./d.js')
							exports.moduleA = require('moduleA')
							exports.moduleB = require('moduleB')
						"""
						'a.js': "module.exports = 'a.js file'"
						'b.js': "module.exports = 'b.js file'"
						'c.js': "module.exports = 'c.js file'"
						'd.js': "module.exports = 'd.js file'"
						'e.js': "module.exports = 'e.js file'"
						'package.json': JSON.stringify
							main: 'main.js'
							browser:
								'a.js': './b.js'
								'c.js': false
								'd.js': './e.js'
						
						'node_modules/moduleA/a.js': "module.exports = 'node.js file'"
						'node_modules/moduleA/b.js': "module.exports = 'browser.js file'"
						'node_modules/moduleA/index.js': "module.exports = require('./a')"
						'node_modules/moduleA/package.json': JSON.stringify
							main: 'index.js'
							browser: './a.js': './b.js'
						
						'node_modules/moduleB/node.js': "module.exports = 'node.js file'"
						'node_modules/moduleB/browser.js': "module.exports = 'browser.js file'"
						'node_modules/moduleB/package.json': JSON.stringify
							main: 'node.js'
							browser: 'browser.js'

				.then ()->
					Promise.all [
						processAndRun file:temp('main.js'), target:'browser'
						processAndRun file:temp('main.js'), target:'node'
					]
				.then ([browser, node])->
					assert.notEqual browser.compiled, node.compiled
					assert.deepEqual node.result,
						a: 'a.js file'
						b: 'b.js file'
						c: 'c.js file'
						d: 'd.js file'
						moduleA: 'node.js file'
						moduleB: 'node.js file'
					
					assert.deepEqual browser.result,
						a: 'b.js file'
						b: 'b.js file'
						c: {}
						d: 'e.js file'
						moduleA: 'browser.js file'
						moduleB: 'browser.js file'


		test "globals won't be shimmed", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							import * as abc from './child'
							global.main = 'mainData';
						"""
						'child.js': """
							module.exports = global.a = typeof Buffer;
						"""

				.then ()->
					Promise.all [
						processAndRun {file:temp('main.js'), usePaths:true, target:'browser'}, null, {Buffer}
						processAndRun {file:temp('main.js'), usePaths:true, target:'node'}, null, {Buffer}
					]

				.then ([browser, node])->
					assert.equal browser.context.main, node.context.main
					assert.equal browser.context.a, node.context.a
					assert.equal browser.context.a, 'function'
					assert.notEqual browser.compiled, node.compiled
					assert.notInclude node.compiled, 'typeof global'
					assert.include browser.compiled, 'typeof global'
					assert.notInclude node.compiled, 'node_modules/buffer'
					assert.include browser.compiled, 'node_modules/buffer'


		test "built-in modules won't be shimmed", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.fs = require('fs');
							exports.os = require('os');
						"""

				.then ()->
					Promise.all [
						processAndRun {file:temp('main.js'), usePaths:true, target:'browser'}, null, {require}
						processAndRun {file:temp('main.js'), usePaths:true, target:'node'}, null, {require}
					]

				.then ([browser, node])->
					assert.notEqual browser.compiled, node.compiled
					assert.typeOf browser.result.os, 'object'
					assert.typeOf node.result.os, 'object'
					assert.notDeepEqual browser.result.os, node.result.os
					assert.equal node.result.os, require('os')
					assert.equal node.result.fs, require('fs')


	suite "importInline statements", ()->
		test "would cause the contents of the import to be inlined prior to transformations & import/export collection", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'mainA.js': """
							switch (input) {
								case 'main':
									output = 'main'; break;
								import 'abc'
								import 'def'
								import 'ghi'
							}
						"""
						'mainB.js': """
							switch (input) {
								case 'main':
									output = 'main'; break;
								importInline 'abc'
								importInline 'def'
								importInline 'ghi'
							}
							import './jkl'
						"""
						'abc.js': """
							case 'abc':
								output = 'abc'; break;
						"""
						'def.js': """
							case 'def':
								output = 'def'; break;
						"""
						'ghi.js': """
							case 'ghi':
								output = 'ghi'; break;
						"""
						'jkl.coffee': """
							class jkl
								constructor: ()-> @bigName = 'JKL'
								importInline './jkl-methods'
						"""
						'jkl-methods.coffee': """
							getName: ()->
								return @bigName
							
							setName: ()->
								@bigName = arguments[0]
						"""

				.then ()-> SimplyImport file:temp('mainA.js')
				.catch ()-> 'failed as expected'
				.then (result)-> assert.equal result, 'failed as expected'
				.then ()-> processAndRun file:temp('mainB.js'), 'mainB.js', {input:'abc'}
				.then ({compiled, result, context, run})->
					assert.equal context.output, 'abc'
					context.input = 'ghi'
					run()
					assert.equal context.output, 'ghi'
					assert.equal typeof context.jkl, 'function'
					instance = new context.jkl
					assert.equal instance.getName(), 'JKL'
					instance.setName('another name')
					assert.equal instance.getName(), 'another name'
		

		test "will not be turned into separate modules if imported more than once", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'mainA.js': """
							abc = import './abc'
							def = import './abc'
							import './ghi'
							ghi = import './ghi'
						"""
						'mainB.js': """
							abc = importInline './abc'
							def = importInline './abc'
							importInline './ghi'
							ghi = importInline './ghi'
						"""
						'abc.js': """
							'abc123'
						"""
						'ghi.js': """
							theGhi = 'ghi789'
						"""

				.then ()->
					Promise.all [
						processAndRun file:temp('mainA.js')
						processAndRun file:temp('mainB.js')
					]
				.spread (bundleA, bundleB)->
					assert.notEqual bundleA.compiled, bundleB.compiled
					assert.include bundleA.compiled, 'require ='
					assert.notInclude bundleB.compiled, 'require ='
					assert.deepEqual bundleA.context, bundleB.context

					context = bundleB.context
					assert.equal context.abc, 'abc123'
					assert.equal context.def, 'abc123'
					assert.equal context.ghi, 'ghi789'
					assert.equal context.theGhi, 'ghi789'
	
	
		test "will have their imports resolved relative to themselves", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							importInline './exportA'
							exports.a = import './a'
							exports.b = import './b $ nested.data'
							importInline './exportC'
							exports.d = (function(){
								return import './d'
							})()
							importInline './exportE'
							exports.other = import 'other.js'
						"""
						'a.js': """
							module.exports = 'abc-value';
						"""
						'a1.js': """
							module.exports = 'ABC-value';
						"""
						'a2.js': """
							module.exports = 'AbC-value';
						"""
						'b.json': """
							{"nested":{"data":"def-value"}}
						"""
						'c.yml': """
							nested:
                              data: 'gHi-value'
						"""
						'd.js': """
							export default jkl = 'jkl-value';
						"""
						'exportA.js': """
							exports.a1 = import 'a1'
							exports.a2 = import 'a2'
						"""
						'exportC.js': """
							exports.c = import 'c $ nested.data'
						"""
						'exportE/index.js': """
							exports.eA = importInline './eA'
							exports.e = import './e'
						"""
						'exportE/eA.js': """
							'Lorem ipsum dolor sit amet, consectetur adipiscing elit.\
							Cras nec malesuada lacus.\
							Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.'
						"""
						'exportE/e/index.js': """
							import './actual $ nested.data'
						"""
						'exportE/e/actual.json': ['b.json', (c)-> c]
						'other.js': """
							export default lmn = 'lmn-value';
						"""

				.then ()-> processAndRun file:temp('main.js'), 'main.js'
				.then ({compiled, result})->
					assert.equal result.a, 'abc-value'
					assert.equal result.a1, 'ABC-value'
					assert.equal result.a2, 'AbC-value'
					assert.equal result.b, 'def-value'
					assert.equal result.c, 'gHi-value'
					assert.equal result.d, 'jkl-value'
					assert.equal result.other, 'lmn-value'


	suite "deduping", ()->
		# suiteTeardown ()-> fs.dirAsync temp(), empty:true 
		
		test "will be enabled by default", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							aaa = import 'module-a';
							bbb = import 'module-b';
							ccc = import 'module-c';
							ddd = import 'module-d';
						"""
						"node_modules/module-a/index.js": """
							module.exports = require('module-c')+'-aaa';
						"""
						"node_modules/module-b/index.js": """
							module.exports = require('module-d')+'-bbb';
						"""
						"node_modules/module-c/index.js": """
							module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
						"""
						"node_modules/module-d/index.js": """
							module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.ccc, context.ddd, 'ccc === ddd'
					assert.equal context.aaa, context.ddd+'-aaa'
					assert.equal context.bbb, context.ddd+'-bbb'
	

		test "will be disabled when options.dedupe is false", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							aaa = import 'module-a';
							bbb = import 'module-b';
							ccc = import 'module-c';
							ddd = import 'module-d';
						"""
						"node_modules/module-a/index.js": """
							module.exports = require('module-c')+'-aaa';
						"""
						"node_modules/module-b/index.js": """
							module.exports = require('module-d')+'-bbb';
						"""
						"node_modules/module-c/index.js": """
							module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
						"""
						"node_modules/module-d/index.js": """
							module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
						"""

				.then ()-> processAndRun file:temp('main.js'), dedupe:false
				.then ({context})->
					assert.notEqual context.ccc, context.ddd, 'ccc !== ddd'
					assert.equal context.aaa, context.ccc+'-aaa'
					assert.equal context.bbb, context.ddd+'-bbb'


	suite "cyclic imports", ()->
		test "are supported between 2-chain imported modules", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						"main.js": """
							aaa = import './a.js';
							bbb = import './b.js';
						"""
						"a.js": """
							var abc;
							exports.result = abc = 100;
							exports.combined = function(){return require('./b.js').result + abc}
						"""
						"b.js": """
							var def;
							exports.result = def = 200;
							exports.combined = function(){return require('./a.js').result + def}
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.typeOf context.aaa, 'object'
					assert.typeOf context.aaa.result, 'number'
					assert.equal context.aaa.result, 100
					assert.equal context.bbb.result, 200
					assert.equal context.aaa.combined(), 300 
					assert.equal context.bbb.combined(), 300
		

		test "are supported between (3+)-chain imported modules", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							aaa = import './a.js';
							//bbb = import './b.js';
							//ccc = import './c.js';
							//ddd = import './d.js';
						"""
						"a.js": """
							module.exports = 'aaa-'+require('./b.js')
						"""
						"b.js": """
							module.exports = 'bbb-'+require('./c.js')
						"""
						"c.js": """
							module.exports = 'ccc-'+require('./d.js')
						"""
						"d.js": """
							module.exports = 'ddd-'+require('./a.js')
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.aaa, 'aaa-bbb-ccc-ddd-[object Object]'
		

		test "are supported between entry file and imported modules", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							var TheLib = new function(){
								this.version = '14';
								this.hyperbole = function(){return this.version*100}
							}
							module.exports = TheLib;
							TheLib.version = (import './a.js')()+'.'+(import './b.js');
							theResult = TheLib.version
						"""
						"a.js": """
							module.exports = function(){return parseFloat(require('./main').version[0]) * 2}
						"""
						"b.js": """
							module.exports = parseFloat(require('./main').version[1]) * require('./main').hyperbole() + require('./a')()
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.theResult, '2.5602'
		

		test "inline imports will be transformed to modules", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							var TheLib = new function(){
								this.version = '14';
								this.hyperbole = function(){return this.version*100}
							}
							module['export'+'s'] = TheLib
							TheLib.version = (import './a.js')()+'.'+(import './b.js');
							TheLib
						"""
						"a.js": """
							aaa = function(){return parseFloat(require('./main').version[0]) * 2}
						"""
						"b.js": """
							parseFloat(require('./main').version[1]) * require('./main').hyperbole() + require('./a')()
						"""

				.then ()-> processAndRun file:temp('main.js'), usePaths:true
				.then ({context, result})->
					assert.equal result.version, '2.5602'



	suite "globals", ()->
		test "the 'global' identifier will be polyfilled if detected in the code", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'mainA.js': """
							abc = import './abc'
							def = require("./def")
							module.exports = abc
							return global
						"""
						'mainB.js': """
							ghi = import './ghi'
							module.exports = ghi
						"""
						'mainC.js': """
							ghi = require('ghi')
							module.exports = typeof global !== 'undefined' ? ghi.toUpperCase() : 'GHI'
						"""
						'abc.js': """
							global.valueABC = 'abc123'
							module.exports = global.valueABC
						"""
						'def.js': """
							module.exports = global.valueDEF = 'def456'
						"""
						"ghi.js": """
							module.exports = 'ghi789'
						"""

			.then ()->
				Promise.all [
					processAndRun file:temp('mainA.js')
					processAndRun file:temp('mainB.js')
					processAndRun file:temp('mainC.js')
				]
			.spread (bundleA, bundleB, bundleC)->
				assert.include bundleA.compiled, require('../lib/builders/strings').globalDec(), 'global dec should be present in bundle A'
				assert.notInclude bundleB.compiled, require('../lib/builders/strings').globalDec(), 'global dec should not be present in bundle B'
				assert.notInclude bundleC.compiled, require('../lib/builders/strings').globalDec(), 'global dec should not be present in bundle C'
				a = Object.exclude bundleA.result, (v,k)-> k is 'global'
				b = Object.exclude bundleA.context, (v,k)-> k is 'global'
				assert.deepEqual a, b
				assert.equal bundleA.context.abc, 'abc123', 'bundleA.abc'
				assert.equal bundleA.context.def, 'def456', 'bundleA.def'
				assert.equal bundleA.context.valueABC, 'abc123', 'bundleA.global.valueABC'
				assert.equal bundleA.context.valueDEF, 'def456', 'bundleA.global.valueDEF'
				assert.equal bundleC.context.ghi, 'ghi789', 'bundleC.ghi'
				assert.equal bundleC.result, 'GHI789', 'bundleC.result'


		test "the 'process' identifier will be polyfilled with a shared module if detected in the code", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'mainA.js': """
							abc = import './abc'
							def = require("./def")
							module.exports = process
						"""
						'mainB.js': """
							ghi = import './ghi'
							module.exports = ghi
							return require('process')
						"""
						'mainC.js': """
							jkl = import './jkl'
							module.exports = jkl
						"""
						'abc.js': """
							process.valueABC = 'abc'
							module.exports = process.valueABC
						"""
						'def.js': """
							process.env.DEFJS = process.browser ? 'DEF' : 'def'
							module.exports = process.env.DEFJS
						"""
						"ghi.js": """
							try {process.value = 'gHi'} catch (e) {}
							module.exports = require('process').valueGHI = 'gHi'
						"""
						"jkl.js": """
							process = typeof process === 'object' ? 'jkl' : 'JKL'
							module.exports = process
						"""

			.then ()->
				Promise.all [
					processAndRun file:temp('mainA.js')
					processAndRun file:temp('mainB.js')
					processAndRun file:temp('mainC.js')
				]
			.spread (bundleA, bundleB, bundleC)->
				assert.equal bundleA.context.abc, 'abc', 'bundleA.abc'
				assert.equal bundleA.context.def, 'DEF', 'bundleA.def'
				assert.typeOf bundleA.result, 'object'
				assert.equal bundleA.result.valueABC, 'abc', 'bundleA.process.valueABC'
				assert.equal bundleA.result.env.DEFJS, 'DEF', 'bundleA.process.env.DEFJS'
				assert.equal bundleB.context.ghi, 'gHi', 'bundleB.ghi'
				assert.equal bundleB.result.valueGHI, 'gHi', 'bundleB.process.valueGHI'
				assert.equal bundleB.result.value, undefined, 'bundleB.process.value'
				assert.equal bundleC.result, 'JKL', 'bundleC.result'


		test "the 'buffer' identifier will be polyfilled with a shared module if detected in the code", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'mainA.js': """
							abc = import './abc'
							def = require("./def")
							module.exports = Buffer
						"""
						'mainB.js': """
							ghi = import './ghi'
							module.exports = ghi
							return require('buffer').Buffer
						"""
						'mainC.js': """
							jkl = import './jkl'
							module.exports = jkl
						"""
						'abc.js': """
							Buffer.valueABC = 'abc'
							module.exports = Buffer.from(Buffer.valueABC)
						"""
						'def.js': """
							Buffer.DEFJS = Buffer.alloc ? 'DEF' : 'def'
							module.exports = Buffer.from(Buffer.DEFJS)
						"""
						"ghi.js": """
							try {Buffer.value = 'gHi'} catch (e) {}
							module.exports = require('buffer').Buffer.valueGHI = 'gHi'
						"""
						"jkl.js": """
							Buffer = typeof Buffer === 'object' ? 'jkl' : 'JKL'
							module.exports = Buffer
						"""

			.then ()->
				Promise.all [
					processAndRun file:temp('mainA.js')
					processAndRun file:temp('mainB.js')
					processAndRun file:temp('mainC.js')
				]
			.spread (bundleA, bundleB, bundleC)->
				assert.notEqual bundleA.result, Buffer, 'bundleA'
				assert.deepEqual bundleA.result.from('test'), Buffer.from('test'), 'buffer instances equality'
				assert.equal bundleA.context.abc.toString(), 'abc', 'bundleA.abc'
				assert.equal bundleA.context.def.toString(), 'DEF', 'bundleA.def'
				assert.typeOf bundleA.result, 'function'
				assert.equal bundleA.result.valueABC, 'abc', 'bundleA.buffer.valueABC'
				assert.equal bundleA.result.DEFJS, 'DEF', 'bundleA.buffer.env.DEFJS'
				assert.equal bundleB.context.ghi, 'gHi', 'bundleB.ghi'
				assert.equal bundleB.result.valueGHI, 'gHi', 'bundleB.buffer.valueGHI'
				assert.equal bundleB.result.value, undefined, 'bundleB.buffer.value'
				assert.equal bundleC.result, 'JKL', 'bundleC.result'


		test "the '__filename' and '__dirname' identifiers will be replaced with the module's relative filename & context", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'nested/main.js': """
							abc = import './abc'
							def = require("./def")
							def2 = require("../def")
							ghi = import 'ghi'
							jkl = import '../nested/inner/jkl'
							lmn = import '../nested/inner/lmn'
							module.exports = {file:__filename, dir:__dirname}
						"""
						'nested/abc.js': """
							module.exports = __filename
						"""
						'nested/def.js': """
							module.exports = __dirname
						"""
						'def.js': """
							module.exports = __dirname
						"""
						"node_modules/ghi/index.js": """
							module.exports = {file:__filename, dir:__dirname}
						"""
						"nested/inner/jkl.js": """
							module.exports = __filename
						"""
						"nested/inner/lmn.js": """
							module.exports = 'no file name'
						"""

			.then ()-> processAndRun file:temp('nested/main.js'), dedupe:false
			.then ({compiled, result, context, writeToDisc})->
				assert.equal context.abc, '/abc.js'
				assert.equal context.def, '/'
				assert.equal context.def2, '/..'
				assert.deepEqual context.ghi, {file:'/../node_modules/ghi/index.js', dir:'/../node_modules/ghi'}
				assert.equal context.jkl, '/inner/jkl.js'
				assert.equal context.lmn, 'no file name'
				assert.deepEqual result, {file:'/main.js', dir:'/'}



	suite "transforms", ()->
		test "provided through-stream transform functions will be passed each file's content prior to import/export scanning", ()->
			through = require('through2')
			customTransform = (file)->
				return through() if file.endsWith('b.js') or file.endsWith('main.js')
				through(
					(chunk, enc, done)->
						@push chunk.toString().toUpperCase()
						done()
					(done)->
						@push "\nmodule.exports = GHI+'-'+(require('./d'))" if file.endsWith('c.js')
						done()
				)

			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
						"""
						'a.js': """
							abc = 'abc-value'
						"""
						'b.js': """
							module.exports = 'def-value'
						"""
						'c.js': """
							ghi = 'ghi-value'
						"""
						'd.js': """
							jkl = 'jkl-value'
						"""
				.then ()-> processAndRun file:temp('main.js'), transform:[customTransform]
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'ABC-VALUE'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'GHI-VALUE-JKL-VALUE'
					assert.notInclude compiled, 'abc-value'


		test "strings resembling the transform file path can be provided in place of a function", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
						"""
						'a.js': """
							abc = 'abc-value'
						"""
						'b.js': """
							module.exports = 'def-value'
						"""
						'c.js': """
							ghi = 'ghi-value'
						"""
				.then ()-> processAndRun file:temp('main.js'), transform:['test/helpers/uppercaseTransform'], specific:{'b.js':{skipTransform:true}, 'main.js':{skipTransform:true}}
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'ABC-VALUE'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'GHI-VALUE'
					assert.notInclude compiled, 'abc-value'


		test "strings resembling the transform module name can be provided in place of a function", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
						"""
						'a.js': """
							abc = 'abc-value'
						"""
						'b.js': """
							module.exports = 'def-value'
						"""
						'c.js': """
							ghi = 'ghi-value'
						"""
						'package.json': '{"main":"entry.js"}'
						'node_modules/uppercase/index.coffee': fs.read './test/helpers/uppercaseTransform.coffee'
				
				.then ()-> processAndRun file:temp('main.js'), transform:['uppercase'], specific:{'b.js':{skipTransform:true}, 'main.js':{skipTransform:true}}
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'ABC-VALUE'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'GHI-VALUE'
					assert.notInclude compiled, 'abc-value'


		test "transforms specified in options.specific will be applied only to the specified file", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
						"""
						'a.js': """
							abc = 'abc-value'
						"""
						'b.js': """
							module.exports = 'def-value'
						"""
						'c.js': """
							ghi = 'ghi-value'
						"""
						'package.json': '{"main":"entry.js", "simplyimport":{"specific":{"c.js":{"transform":"test/helpers/uppercaseTransform"}}}}'
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'abc-value'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'GHI-VALUE'


		test "transforms specified in package.json's browserify.transform field will be applied to imports of that package", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'package.json': JSON.stringify browserify:{transform:'test/helpers/replacerTransform'}
						'main.js': """
							a = import 'module-a'
							b = import 'module-b'
							c = import './c'
							d = 'gHi'
						"""
						'c.js': """
							ghi = 'gHi-value'
						"""
					
						'node_modules/module-a/package.json': JSON.stringify browserify:{transform:['test/helpers/lowercaseTransform']}
						'node_modules/module-a/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-a/a.js': """
							result = 'gHi-VALUE'
						"""
					
						'node_modules/module-b/package.json': JSON.stringify browserify:{transform:[["test/helpers/replacerTransform", {someOpt:true}]]}
						'node_modules/module-b/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-b/a.js': """
							result = 'gHi-VALUE'
						"""
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a.a, 'ghi-value'
					assert.equal context.a.b, 'value-ghi'
					assert.equal context.b.a, 'GhI-VALUE'
					assert.equal context.b.b, 'vaLUe-GhI'
					assert.equal context.c, 'GhI-value'
					assert.equal context.d, 'GhI'


		test "global transforms will be applied to all processed files", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							A = import './a'
							b = import './b'
							C = import './c'
							d = import 'mODULe-A'
						"""
						'a.js': """
							abc = 'abc-VALUE'
						"""
						'b.js': """
							module.exports = 'DEF-value'
						"""
						'c.js': """
							GHI = 'ghi-VALUE'
						"""
						'node_modules/module-a/index.js': """
							exports.a = imPORt './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-a/a.js': """
							result = 'gHi-VALUE'
						"""
				
				.then ()-> processAndRun file:temp('main.js'), globalTransform:[helpers.lowercaseTransform]
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'abc-value'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'ghi-value'
					assert.equal context.d.a, 'ghi-value'
					assert.equal context.d.b, 'value-ghi'
					assert.equal context.A, undefined


		test "final transforms will be applied to the final bundled file", ()->
			receivedFiles = []
			receivedContent = []
			customTransform = (file)->
				receivedFiles.push(file)
				return (content)->
					receivedContent.push(result=content.toLowerCase())
					return result

			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							A = import './a'
							b = import './b'
							C = import './c'
							d = import 'module-a'
						"""
						'a.js': """
							abc = 'abc-VALUE'
						"""
						'b.js': """
							module.exports = 'DEF-value'
						"""
						'c.js': """
							GHI = 'ghi-VALUE'
						"""
						'node_modules/module-a/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-a/a.js': """
							result = 'gHi-VALUE'
						"""
				
				.then ()-> processAndRun file:temp('main.js'), finalTransform:[customTransform]
				.then ({context, compiled, writeToDisc})->
					assert.deepEqual receivedFiles, [temp('main.js')]
					assert.equal receivedContent.length, 1
					assert.equal receivedContent[0], compiled
					assert.equal context.a, 'abc-value'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'ghi-value'
					assert.equal context.d.a, 'ghi-value'
					assert.equal context.d.b, 'value-ghi'
					assert.equal context.A, undefined


		test "transforms specified in package.json will be applied", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': "module.exports = import './child'"
						'child.js': "module.exports = 'gHi'"
						'external.js': "module.exports = import 'module'"
						'node_modules/module/index.js': "module.exports = 'gHi'"
						'node_modules/module/package.json': JSON.stringify simplyimport:{transform:'test/helpers/replacerTransform'}
				
				.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{transform:'test/helpers/replacerTransform'}
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})-> assert.equal result, 'GhI'
				
				.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{globalTransform:'test/helpers/replacerTransform'}
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})-> assert.equal result, 'GhI'
				
				.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{finalTransform:'test/helpers/replacerTransform'}
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})-> assert.equal result, 'GhI'
				
				.then ()-> processAndRun file:temp('main.js'), noPkgConfig:true
				.then ({result})-> assert.equal result, 'gHi'
				
				.then ()-> processAndRun file:temp('main.js'), noPkgConfig:true, transform:'test/helpers/replacerTransform'
				.then ({result})-> assert.equal result, 'GhI'
				
				.then ()-> helpers.lib 'package.json': JSON.stringify main:'index.js'
				.then ()-> processAndRun file:temp('external.js')
				.then ({result})-> assert.equal result, 'GhI'


		test "transforms will receive the file's full path as the 1st argument", ()->
			received = null
			customTransform = (file)->
				received = file
				require('through2')()

			Promise.resolve()
				.then ()->
					helpers.lib
						'abc.js': "'abc-value'"
						'deff/index.js': "'def-value'"
				
				.then ()-> assert.equal received, null
				.then ()-> SimplyImport src:"import './abc'", context:temp(), transform:customTransform
				.then ()-> assert.equal received, temp('abc.js')
				.then ()-> SimplyImport src:"import 'deff'", context:temp(), transform:customTransform
				.then ()-> assert.equal received, temp('deff/index.js')


		test "transforms will receive the tasks's options object as the 2nd argument under the _flags property", ()->
			received = null
			customTransform = (file, opts)->
				received = opts
				require('through2')()

			Promise.resolve()
				.then ()->
					helpers.lib
						'abc.js': "'abc-value'"
						'def/index.js': "'def-value'"
				
				.then ()-> assert.equal received, null
				.then ()-> SimplyImport src:"import './abc'", context:temp(), transform:customTransform
				.then ()->
					assert.typeOf received, 'object'
					assert.typeOf received._flags, 'object'
					assert.equal received._flags.src, "import './abc'"
					assert.equal received._flags.transform[0], customTransform


		test "transforms will receive the file's internal object as the 3rd argument", ()->
			received = null
			customTransform = (file, opts, file_)->
				received = file_
				require('through2')()

			Promise.resolve()
				.then ()->
					helpers.lib
						'deff/index.js': "'def-value'"
				
				.then ()-> assert.equal received, null
				.then ()-> SimplyImport src:"import './deff'", context:temp(), transform:customTransform
				.then ()->
					assert.typeOf received, 'object'
					assert.equal received.pathAbs, temp('deff/index.js')
					assert.equal received.path, Path.relative process.cwd(), temp('deff/index.js')
					assert.equal received.pathExt, 'js'
					assert.equal received.pathBase, 'index.js'
					assert.equal received.content, "'def-value'"


		test "transforms will receive the file's content as the 4rd argument", ()->
			received = null
			target = null
			customTransform = (file, opts, file_, content)->
				received = content if file is target
				require('through2')()

			Promise.resolve()
				.then ()->
					helpers.lib
						'abcc/index.js': "module.exports = 'def-value'"
						'deff/index.js': "import '../abcc'"
				
				.then ()-> assert.equal received, null
				.then ()-> target = temp('abcc/index.js')
				.then ()-> SimplyImport src:"importInline './abcc'", context:temp(), transform:customTransform
				.then ()-> assert.equal received, null
				.then ()-> SimplyImport src:"import './abcc'", context:temp(), transform:customTransform
				.then ()-> assert.equal received, "module.exports = 'def-value'"
				
				.then ()-> target = temp('deff/index.js')
				.then ()-> SimplyImport src:"import './deff'", context:temp(), transform:customTransform
				.then ()-> assert.equal received, "_$sm('../abcc' )"


		test "transforms can return a string", ()->
			customTransform = (file, o, d, content)->
				content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"

			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.first = import './abc'
							exports.second = import './deff'
							exports.third = import './ghi'
						"""
						'abc.js': "'abc-value'"
						'deff/index.js': "'def-value'"
						'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
				
				.then ()-> processAndRun file:temp('main.js'), transform:customTransform
				.then ({result})->
					assert.equal result.first, 'ABC---value'
					assert.equal result.second, 'DEF---value'
					assert.equal result.third, 'GHI---value___JKL---value'


		test "transforms can return a function which will be invoked with the file's content", ()->
			customTransform = (file)->
				assert.include file, temp()
				return (content)->
					content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"

			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.first = import './abc'
							exports.second = import './deff'
							exports.third = import './ghi'
						"""
						'abc.js': "'abc-value'"
						'deff/index.js': "'def-value'"
						'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
				
				.then ()-> processAndRun file:temp('main.js'), transform:customTransform
				.then ({result})->
					assert.equal result.first, 'ABC---value'
					assert.equal result.second, 'DEF---value'
					assert.equal result.third, 'GHI---value___JKL---value'


		test "transforms can return a promise who's value will be followed (function or string)", ()->
			customTransformA = (file, o, d, content)->
				Promise.resolve()
					.delay(10)
					.then ()-> content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"
					.delay(5)
			
			customTransformB = (file)->
				Promise.resolve()
					.delay(10)
					.then -> (content)-> content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"
					.delay(5)

			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.first = import './abc'
							exports.second = import './deff'
							exports.third = import './ghi'
						"""
						'abc.js': "'abc-value'"
						'deff/index.js': "'def-value'"
						'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
				
				.then ()->
					Promise.all [
						processAndRun file:temp('main.js'), transform:customTransformA
						processAndRun file:temp('main.js'), transform:customTransformB
					]
				.then ([moduleA, moduleB])->
					assert.equal moduleA.result.first, 'ABC---value'
					assert.equal moduleA.result.second, 'DEF---value'
					assert.equal moduleA.result.third, 'GHI---value___JKL---value'
					assert.deepEqual moduleA.result, moduleB.result


		test "coffeescript files will be automatically transformed by default", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
							d = import 'module-a'
						"""
						'a.coffee': """
							do ()-> abc = 'abc-value'
						"""
						'b/index.coffee': """
							module.exports = do ()-> abc = 456; require '../c'
						"""
						'c.coffee': """
							module.exports = importInline './c2'
						"""
						'c2.coffee': "'DEF-value'"
						
						'node_modules/module-a/package.json': '{"main":"./index.coffee"}'
						'node_modules/module-a/index.coffee': """
							module.exports.a = false or 'maybe'
							import {output as innerModule} from './inner'
							module.exports.b = innerModule
						"""
						'node_modules/module-a/inner.js': """
							var mainOutput = (function(){return 'inner-value'})()
							var otherOutput = 'another-value'
							export {mainOutput as output, otherOutput}
						"""
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'abc-value'
					assert.equal context.abc, undefined
					assert.equal context.b, 'DEF-value'
					assert.equal context.c, 'DEF-value'
					assert.equal context.d.a, 'maybe'
					assert.equal context.d.b, 'inner-value'


		test "typescript files will be automatically transformed by default", ()->
			Promise.resolve()
				.then ()-> fs.dir temp(), empty:true
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = import './b'
							c = import './c'
							d = import 'module-a'
						"""
						'a.ts': """
							function returner(label: string) {return label+'-value'}
							export = returner('abc');
						"""
						'b/index.ts': """
							function exporter(obj?: {a:string, b:string}) {
								var result;
								import * as result from '../c'
								return result;
							}
							var result = exporter()
							export = result
						"""
						'c.ts': """
							export = importInline './c2'
						"""
						'c2.ts': "add = {'a':'def-value', 'b':'ghi-value'}"
						
						'node_modules/module-a/package.json': '{"main":"./index.ts"}'
						'node_modules/module-a/index.ts': """
							function extract(): string {
								return 'maybe';
							}
							export var a = extract()
							var innerModule;
							import {output as innerModule} from './inner'
							export var b = innerModule;
						"""
						'node_modules/module-a/inner.js': """
							var mainOutput = (function(){return 'inner-value'})()
							var otherOutput = 'another-value'
							export {mainOutput as output, otherOutput}
						"""
				
				.then ()-> processAndRun file:temp('main.js'), usePaths:true
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'abc-value'
					assert.equal context.b.a, 'def-value'
					assert.equal context.b.b, 'ghi-value'
					assert.equal context.c.a, 'def-value'
					assert.equal context.c.b, 'ghi-value'
					assert.equal context.d.a, 'maybe'
					assert.equal context.d.b, 'inner-value'


		test "cson files will be automatically transformed by default", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.cson'
							b = require('b')
							b2 = import './b'
						"""
						'a.cson': """
							dataA:
								abc123: 1
								def456: 2
						"""
						'b/index.cson': """
							dataB: [
								4
								0
								1
							]
							dataB2: 123
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.deepEqual context.a, {dataA: {abc123:1, def456:2}}
					assert.deepEqual context.b, {dataB:[4,0,1], dataB2:123}


		test "yml files will be automatically transformed by default", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a'
							b = require('b')
							b2 = import './b'
						"""
						'a.yml': """
							dataA:
							  abc123: 1
							  def456: 2
						"""
						'b/index.yml': """
							dataB:
							  - 4
							  - 0
							  - 1
							dataB2: 123
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.deepEqual context.a, {dataA: {abc123:1, def456:2}}
					assert.deepEqual context.b, {dataB:[4,0,1], dataB2:123}


		test "transforms named in options.ignoreTransform will be skipped", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							a = 'abc-value'
							b = 'def-value'
						"""
						'package.json': '{"main":"entry.js"}'
						'node_modules/abc-replacer/index.js': """
							module.exports = function(a,b,c,content){
								return content.replace(/abc-value/g, 'ABC---value')
							}
						"""
						'node_modules/def-replacer/index.js': """
							module.exports = function(a,b,c,content){
								return content.replace(/def-value/g, 'DEF---value')
							}
						"""
				.then ()->
					Promise.all [
						processAndRun file:temp('main.js'), transform:['abc-replacer', 'def-replacer']
						processAndRun file:temp('main.js'), transform:['abc-replacer', 'def-replacer'], ignoreTransform:['abc-replacer']
					]
				.then ([bundleA, bundleB])->
					assert.notEqual bundleA.compiled, bundleB.compiled
					assert.equal bundleA.context.a, 'ABC---value'
					assert.equal bundleA.context.b, 'DEF---value'
					assert.equal bundleB.context.a, 'abc-value'
					assert.equal bundleB.context.b, 'DEF---value'


		suite "popular transforms", ()-> # testing some real-world scenarios
			test "envify", ()->
				Promise.resolve()
					.then ()->
						helpers.lib
							'main.js': """
								exports.main = process.env.VAR1
								if (process.env.VAR2 === 'chocolate') {
									a = import 'module-a'
								} 
								b = require('module-b')
							"""
							'node_modules/module-a/index.js': """
								module.exports = JSON.parse(process.env.VAR3)
							"""
							'node_modules/module-b/index.js': """
								process.env.VAR4
							"""
					.then ()->
						process.env.VAR1 = 'the main file'
						process.env.VAR2 = 'chocolate'
						process.env.VAR3 = '{"a":10, "b":20, "c":30}'
						process.env.VAR4 = 'the last env var'
						processAndRun file:temp('main.js'), transform:'envify', specific: 'module-a':{transform:['envify']},'module-b':{transform:['envify']}
					
					.then ({result, context, writeToDisc})->
						assert.equal result.main, 'the main file'
						assert.deepEqual context.a, {a:10,b:20,c:30}
						assert.equal context.b, 'the last env var'
		
			test "envify+options.env", ()->
				Promise.resolve()
					.then ()->
						helpers.lib
							'main.js': """
								exports.main = process.env.VAR1
								if (process.env.VAR2 === 'chocolate') {
									a = import 'module-a'
								} 
								b = require('module-b')
							"""
							'node_modules/module-a/index.js': """
								module.exports = JSON.parse(process.env.VAR3)
							"""
							'node_modules/module-b/index.js': """
								process.env.VAR4
							"""
							"customEnv": """
								VAR1=the main file
								VAR2=chocolate
								VAR3={"a":10, "b":20, "c":30}
							"""
					.then ()->
						delete process.env.VAR1
						delete process.env.VAR2
						delete process.env.VAR3
						delete process.env.VAR4
						process.env.VAR4 = 'the last env var'
						processAndRun file:temp('main.js'), globalTransform:'envify', env:temp('customEnv')
					
					.then ({result, context, writeToDisc})->
						assert.equal result.main, 'the main file'
						assert.deepEqual context.a, {a:10,b:20,c:30}
						assert.equal context.b, 'the last env var'
		

			test "brfs", ()->
				Promise.resolve()
					.then ()->
						helpers.lib
							'main.js': """
								main = require('fs').readFileSync(__dirname+'/first.html', 'utf8')
								a = import './a'
								b = import './b'
								c = b.toUpperCase()
							"""
							'a.js': """
								module.exports = require('fs').readFileSync(__dirname+'/second.html', 'utf8')
							"""
							'b.js': """
								require('fs').readFileSync(__dirname+'/third.html', 'utf8')
							"""
							'first.html': "<p>beep boop</p>"
							'second.html': "<div class=\"wrapper\">\n<p>beep boop</p>\n</div>"
							'third.html': "<div id='superWrapper'>\n<div class=\"wrapper\">\n<p>beep boop</p>\n</div>\n</div>"
					.then ()-> processAndRun file:temp('main.js'), transform:'brfs'
					.then ({context, writeToDisc})->
						assert.equal context.main, fs.read temp 'first.html'
						assert.equal context.a, fs.read temp 'second.html'
						assert.equal context.b, third=fs.read temp 'third.html'
						assert.equal context.c, third.toUpperCase()


			test "es6ify", ()->
				@skip() if nodeVersion < 6
				Promise.resolve()
					.then ()->
						helpers.lib
							'main.js': """
								var {first, second} = import './a'
								class Custom {
									constructor(name) {
										this.name = name
									}
								}
								require('./b')
								exports.b = b
								exports.first = first
								exports.second = second
								exports.Custom = Custom
							"""
							'a.js': """
								var first = 'theFirst', second = 'theSecond';
								module.exports = {first, second}
							"""
							'b.js': """
								var b = function(a,b = 10){return a * b}
							"""
					.then ()-> processAndRun file:temp('main.js'), transform:'es6ify'
					.then ({compiled, result, context, writeToDisc})->
						assert.equal result.first, 'theFirst'
						assert.equal result.second, 'theSecond'
						assert.equal (new result.Custom 'dan').name, 'dan'
						assert.equal result.b(15), 150
						assert.equal result.b(15, 4), 60
						assert.notInclude compiled, 'class'



	suite "extraction", ()->
		suiteSetup emptyTemp
		
		test "specific fields can be imported from JSON files by specifying a property after the file path separated by '$'", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json$dataPointA'
							b = require('b.json$dataPointB')
							c = require('./c$dataPointC')
						"""
						'a.json': """
							{
								"dataPointA": {"a":1, "A":10, "AA":100},
								"dataPointB": {"b":2, "B":20, "BB":200},
								"dataPointC": {"c":3, "C":30, "CC":300}
							}
						"""
						'b.json': """
							{
								"dataPointA": {"a":1, "A":10, "AA":100},
								"dataPointB": {"b":2, "B":20, "BB":200},
								"dataPointC": {"c":3, "C":30, "CC":300}
							}
						"""
						'c.json': """
							{
								"dataPointA": {"a":1, "A":10, "AA":100},
								"dataPointB": {"b":2, "B":20, "BB":200},
								"dataPointC": {"c":3, "C":30, "CC":300}
							}
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.notInclude compiled, 'require ='
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.typeOf context.c, 'object'
					assert.deepEqual context.a, {"a":1, "A":10, "AA":100}
					assert.deepEqual context.b, {"b":2, "B":20, "BB":200}
					assert.deepEqual context.c, {"c":3, "C":30, "CC":300}


		test "extraction properties can be deep", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json$dataPointA.simply import.abc[1]'
							b = require('b.json$dataPointB[13-seep].def[0]')
						"""
						'a.json': """
							{
								"dataPointA": {"a":1, "A":10, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
								"dataPointB": {"b":2, "B":20, "BB":200}
							}
						"""
						'b.json': """
							{
								"dataPointA": {"a":1, "A":10, "AA":100},
								"dataPointB": {"b":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "BB":100}
							}
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.notInclude compiled, 'require ='
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}


		test "the '$' separator can have whitespace surrounding it", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json   $ dataPointA.simply import.abc[1]'
						"""
						'a.json': """
							{
								"dataPointA": {"a":1, "A":10, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
								"dataPointB": {"b":2, "B":20, "BB":200}
							}
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.notInclude compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.typeOf context.a, 'object'
					assert.deepEqual context.a, {"ABC":456}


		test "duplicate imports when all are extraction imports", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json $ dataPointA.simply import.abc[1]'
							b = require('a.json $ dataPointA[13-seep].def[0]')
						"""
						'a.json': """
							{
								"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
								"dataPointB": {"b":2, "B":20, "BB":200}
							}
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.notInclude compiled, 'abc123'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}


		test "duplicate imports when some are extraction imports", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json $ dataPointA.simply import.abc[1]'
							b = require('a.json $ dataPointA["13-seep"].def[0]')
							c = require('a.json')
						"""
						'a.json': """
							{
								"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
								"dataPointB": {"b":2, "B":20, "BB":200}
							}
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.include compiled, 'dataPointB'
					assert.include compiled, 'abc123'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.typeOf context.c, 'object'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}
					assert.equal context.c['dataPointA.simply import.abc[1]'], context.a
					assert.equal context.c['dataPointA[13-seep].def[0]'], context.b


		test "invalid syntax data files will cause ParseError to be thrown", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.json $ dataPointA'
						"""
						'a.json': """
							{
								"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
								"dataPointB": {"b:2, "B":20, BB:200}
							}
						"""
				.then ()-> SimplyImport file:temp('main.js')
				.catch (err)-> assert.include(err.message, 'Unexpected'); 'failed as expected'
				.then (result)-> assert.equal result, 'failed as expected'


		test "data can be extracted from cson files", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							import './insertA'
							b = require('a.cson $ dataPointA[13-seep].def[0]')
							c = require('b.cson$dataPointC.inner')
						"""
						'insertA.js': """
							a = import './a.cson $ dataPointA.simply import.abc[1]'
						"""
						'a.cson': """
							dataPointA:
								abc123: 1
								'13-seep':
									def:[
										{"DEF":123}
										{"DEF":456}
									]
								"simply import":{"abc":[{"ABC":123},{"ABC":456}]}
							
							"dataPointB": {"b":2, "B":20, "BB":200}
						"""
						'b.cson': """
							dataPointC:
								inner: 'theString'
							dataPointD:
								inner: 30
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.notInclude compiled, 'abc123'
					assert.notInclude compiled, 'dataPointD'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.typeOf context.c, 'string'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}
					assert.deepEqual context.c, 'theString'


		test "data can be extracted from yml files", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							importInline './insertA'
							b = require('a.yml $ dataPointA[13-seep].def[0]')
							c = require('b.yml$dataPointC.inner')
						"""
						'insertA.js': """
							a = import './a.yml $ dataPointA.simply import.abc[1]'
						"""
						'a.yml': """
							dataPointA:
							  abc123: 1
							  13-seep:
							    def:
							      - DEF: 123
							      - DEF: 456
							  simply import:
							    abc:
							      - ABC: 123
							      - ABC: 456

							dataPointB:
							  b:2
							  B:20
							  BB:200
						"""
						'b.yml': """
							dataPointC:
							  inner: 20
							dataPointD:
							  inner: 30
						"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					writeToDisc()
					assert.include compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.notInclude compiled, 'abc123'
					assert.notInclude compiled, 'dataPointD'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.typeOf context.c, 'number'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}
					assert.deepEqual context.c, 20


		test "entry files of data types will support importInline statements", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.json': """
						{
							"main": "index.js",
							"version": "1.0.0",
							"a": importInline "./a-file",
							"size": "12",
							"b": importInline "./b-file"
						}
						"""
						'a-file.json': """
						{
							"main": "a.js",
							"version": "2.0.0"
						}
						"""
						'b-file.json': """
						{
							"main": "b.js",
							"version": "3.0.0"
						}
						"""

				.then ()-> SimplyImport file:temp('main.json')
				.then (compiled)->
					parsed = null
					assert.notInclude compiled, 'require'
					assert.doesNotThrow ()-> parsed = JSON.parse(compiled)
					assert.equal parsed.main, 'index.js'
					assert.equal parsed.version, '1.0.0'
					assert.equal parsed.size, '12'
					assert.equal parsed.a.main, 'a.js'
					assert.equal parsed.b.main, 'b.js'
					assert.equal parsed.a.version, '2.0.0'
					assert.equal parsed.b.version, '3.0.0'



	suite "conditionals", ()->
		test "conditional blocks are marked by start/end comments and are removed if the statement in the start comment is falsey", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							abc = 'aaa';

							// simplyimport:if VAR_A
							def = 'bbb';
							abc = def.slice(1)+abc.slice(2).toUpperCase()
							// simplyimport:end

							// simplyimport:if VAR_B
							ghi = 'ccc';
							abc = ghi.slice(1)+abc.slice(2).toUpperCase()
							// simplyimport:end

							result = abc;
						"""

				.then ()->
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'aaa'
					assert.equal context.def, undefined
					assert.equal context.ghi, undefined
					assert.equal context.result, context.abc
				
				.then ()->
					process.env.VAR_A = 1
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'bbA'
					assert.equal context.def, 'bbb'
					assert.equal context.ghi, undefined
					assert.equal context.result, context.abc
				
				.then ()->
					process.env.VAR_B = 1
					processAndRun file:temp('main.js')
				.then ({context, compiled})->
					assert.equal context.abc, 'ccA'
					assert.equal context.def, 'bbb'
					assert.equal context.ghi, 'ccc'
					assert.equal context.result, context.abc
					assert.notInclude compiled, 'simplyimport'


		test "names in statements will be treated as env variables", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							abc = 'aaa';

							// simplyimport:if somevar = 'abc'
							abc = 'bbb';
							// simplyimport:end
						"""

				.then ()->
					process.env.somevar = '123'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'aaa'

				.then ()->
					process.env.somevar = 'abc'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'bbb'


		test "BUNDLE_TARGET in statements will be resolved to the task's options.target", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							a = 'nothing';
							b = '';
							c = '';
							d = 'nothing';

							// simplyimport:if bundle_target = 'node'
							a = 'node';
							// simplyimport:end

							// simplyimport:if bundle_TARGET = 'browser'
							a = 'browser';
							// simplyimport:end

							// simplyimport:if BUNDLE_TARGET = 'node'
							b = 'node';
							c = 'node';
							// simplyimport:end

							// simplyimport:if BUNDLE_TARGET === 'browser'
							b = 'browser';
							c = 'browser';
							// simplyimport:end

							// simplyimport:if BUNDLE_TARGET = 'something-else'
							d = 'something';
							// simplyimport:end
						"""

				.then ()->
					assert.equal typeof process.env.BUNDLE_TARGET, 'undefined'
					processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.a, 'nothing'
					assert.equal context.b, 'browser'
					assert.equal context.c, 'browser'
					assert.equal context.d, 'nothing'

				.then ()->
					assert.equal typeof process.env.BUNDLE_TARGET, 'undefined'
					processAndRun file:temp('main.js'), target:'node'
				.then ({context})->
					assert.equal context.a, 'nothing'
					assert.equal context.b, 'node'
					assert.equal context.c, 'node'
					assert.equal context.d, 'nothing'

				.then ()->
					process.env.BUNDLE_TARGET = 'something-else'
					processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.a, 'nothing'
					assert.equal context.b, 'browser'
					assert.equal context.c, 'browser'
					assert.equal context.d, 'nothing'


		test "statements will be parsed as js expressions and can thus can have standard punctuators and invoke standard globals", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							abc = 'aaa';

							// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
							abc = 'bbb';
							// simplyimport:end

							// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
							def = 'def';
							// simplyimport:end
						"""

				.then ()->
					process.env.VAR_A = 'abc'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'aaa'
					assert.equal context.def, undefined

				.then ()->
					process.env.VAR_B = 'def'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'bbb'
					assert.equal context.def, undefined

				.then ()->
					process.env.VAR_C = 'ghi'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'bbb'
					assert.equal context.def, 'def'


		test "punctuator normalization (=|==|=== -> ==), (!=|!== -> !=), (| -> ||), (& -> &&)", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							aaa = 'aaa';

							// simplyimport:if VAR_A = 'abc' | VAR_A === 123
							bbb = 'bbb';
							// simplyimport:end

							// simplyimport:if typeof VAR_B = 'string' & VAR_B === 40 && parseFloat(VAR_C) !== 1.58 & parseFloat(VAR_C) === '12.58'
							ccc = 'ccc';
							// simplyimport:end

							// simplyimport:if typeof VAR_C == 'object' | typeof parseInt(VAR_C) == 'number'
							ddd = 'ddd';
							// simplyimport:end

							// simplyimport:if isNaN(VAR_D) & typeof parseInt(VAR_C) == 'number' && Boolean(12) = true
							eee = 'eee';
							// simplyimport:end

							// simplyimport:if parseInt(VAR_E) == 3 && VAR_E.split('.')[1] === 23
							fff = 'fff';
							// simplyimport:end
						"""

				.then ()->
					process.env.VAR_A = '123'
					process.env.VAR_B = '40'
					process.env.VAR_C = '12.58'
					process.env.VAR_D = 'TEsT'
					process.env.VAR_E = '3.23.10'
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'ccc'
					assert.equal context.ddd, 'ddd'
					assert.equal context.eee, 'eee'
					assert.equal context.fff, 'fff'


		test "if a 'simplyimport:end' comment is missing then it will be auto inserted at the file's end", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							aaa = 'aaa';

							// simplyimport:if var1
							bbb = 'bbb';
							// simplyimport:end

							// simplyimport:if !var2
							ccc = 'ccc';


							var result = aaa
						"""

				.then ()->
					process.env.var1 = true
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					writeToDisc()
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'ccc'
					assert.equal context.result, undefined

				.then ()->
					process.env.var2 = true
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, undefined
					assert.equal context.result, undefined


		test "conditional statements will be processed prior to force inline imports", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							abc = importInline "./a.js";

							// simplyimport:if var3
							importInline "./b"
							// simplyimport:end

							// simplyimport:if !var4
							importInline "./c"
							// simplyimport:end

							// simplyimport:if !var5
							importInline "./c"
							import "./d"
							// simplyimport:end

							// simplyimport:if var5
							importInline "./e"
							// simplyimport:end
						"""

						"a.js": "aaa = 'aaa'"
						"b.js": "bbb = 'bbb'"
						"c.js": "ccc = 'ccc'"
						"d.js": "ddd = 'ddd'"
						"e.js": "eee = 'eee'"

				.then ()->
					process.env.var5 = 2
					processAndRun file:temp('main.js')
				.then ({context, writeToDisc})->
					assert.equal context.abc, 'aaa'
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, undefined
					assert.equal context.ccc, 'ccc'
					assert.equal context.ddd, undefined
					assert.equal context.eee, 'eee'


		test "all conditionals will be included when options.matchAllConditions is set", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						"main.js": """
							abc = 'aaa';

							// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
							abc = 'bbb';
							// simplyimport:end

							// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
							def = 'def';
							// simplyimport:end

							// simplyimport:if VAR_C
							ghi = 'ghi';
							// simplyimport:end

							// simplyimport:if VAR_A == 'gibberish'
							jkl = 'jkl';
							// simplyimport:end
						"""

				.then ()->
					process.env.VAR_A = 'abc'
					delete process.env.VAR_B
					delete process.env.VAR_C
					processAndRun file:temp('main.js'), matchAllConditions:true

				.then ({context, writeToDisc})->
					assert.equal context.abc, 'bbb'
					assert.equal context.def, 'def'
					assert.equal context.ghi, 'ghi'
					assert.equal context.jkl, 'jkl'


		suite "with custom options.env", ()->
			suiteSetup ()-> helpers.lib
				'main.js': """
					// simplyimport:if VAR_A = 'AAA'
					exports.a = 'aaa'
					// simplyimport:end

					// simplyimport:if VAR_B = 'bbb'
					exports.b = 'bbb'
					// simplyimport:end

					// simplyimport:if VAR_C = 'CCC'
					exports.c = 'ccc'
					// simplyimport:end

					// simplyimport:if VAR_D = 'DDD'
					exports.d = 'ddd'
					// simplyimport:end
				"""
				'myEnv': """
					VAR_A=AAA
					VAR_C=CCC
					VAR_D=ddd
				"""

			test "options.env = object", ()->
				Promise.resolve()
					.then ()->
						delete process.env.VAR_A
						delete process.env.VAR_B
						process.env.VAR_B = 'bbb'
						process.env.VAR_C = 'ccc'
						process.env.VAR_D = 'CCC'
						processAndRun file:temp('main.js'), env:{VAR_A:'AAA', VAR_C:'CCC', VAR_D:'ddd'}

					.then ({result})->
						assert.equal process.env.VAR_A, undefined
						assert.equal process.env.VAR_B, 'bbb'
						assert.equal process.env.VAR_C, 'ccc'
						assert.equal process.env.VAR_D, 'CCC'
						assert.deepEqual result,
							a: 'aaa'
							b: 'bbb'
							c: 'ccc'

			test "options.env = filepath", ()->
				Promise.resolve()
					.then ()->
						delete process.env.VAR_A
						delete process.env.VAR_B
						process.env.VAR_B = 'bbb'
						process.env.VAR_C = 'ccc'
						process.env.VAR_D = 'CCC'
						processAndRun file:temp('main.js'), env:temp('myEnv')

					.then ({result})->
						assert.equal process.env.VAR_A, undefined
						assert.equal process.env.VAR_B, 'bbb'
						assert.equal process.env.VAR_C, 'ccc'
						assert.equal process.env.VAR_D, 'CCC'
						assert.deepEqual result,
							a: 'aaa'
							b: 'bbb'
							c: 'ccc'

			test "options.env = filepath from package.json", ()->
				Promise.resolve()
					.then ()-> helpers.lib
						'package.json': JSON.stringify(simplyimport:env:'myEnv')
					.then ()->
						delete process.env.VAR_A
						delete process.env.VAR_B
						process.env.VAR_B = 'bbb'
						process.env.VAR_C = 'ccc'
						process.env.VAR_D = 'CCC'
						processAndRun file:temp('main.js')

					.then ({result})->
						assert.equal process.env.VAR_A, undefined
						assert.equal process.env.VAR_B, 'bbb'
						assert.equal process.env.VAR_C, 'ccc'
						assert.equal process.env.VAR_D, 'CCC'
						assert.deepEqual result,
							a: 'aaa'
							b: 'bbb'
							c: 'ccc'


	suite "core module shims", ()->
		test "assert", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('assert')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'function'
					assert.doesNotThrow ()-> result.ok(true)
					assert.throws ()-> result.ok(false)
					assert.doesNotThrow ()-> result.deepEqual([10,20,30], [10,20,30])
					assert.throws ()-> result.deepEqual([10,20,30,40],[10,20,30])


		test "buffer", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('buffer')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					result = result.Buffer
					assert.typeOf result, 'function'
					assert.doesNotThrow ()-> result.from('test')
					assert.equal 0, result.compare result.from('test'), result.from('test')


		test "console", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('console')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.log, 'function'
					assert.doesNotThrow ()-> result.log 'test'
					assert.doesNotThrow ()-> result.warn 'test'
					assert.doesNotThrow ()-> result.trace 'test'


		test "constants", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('constants')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					keys = Object.keys result
					assert.include keys, 'NPN_ENABLED'
					assert.include keys, 'F_OK'
					assert.include keys, 'DH_NOT_SUITABLE_GENERATOR'


		test "domain", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('domain')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.create, 'function'
					assert.doesNotThrow ()-> result.create()


		test "events", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('events')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'function'
					assert.doesNotThrow ()-> new result()
					assert.deepEqual (new result())._events, (new (require 'events'))._events


		test "http", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('http')"
				.then ()-> processAndRun file:temp('main.js'), usePaths:true, null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
				.then ({result, writeToDisc})->
					assert.typeOf result, 'object'
					assert.typeOf result.get, 'function'
					result.get('http://google.com').abort()


		test "https", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('https')"
				.then ()-> processAndRun file:temp('main.js'), usePaths:true, null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
				.then ({result, writeToDisc})->
					assert.typeOf result, 'object'
					assert.typeOf result.get, 'function'
					result.get('https://google.com').abort()


		test "util", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('util')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.isArray, 'function'
					assert.equal result.isArray([]), require('util').isArray([])
					assert.equal result.isArray({}), require('util').isArray({})


		test "os", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('os')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.uptime, 'function'
					assert.equal result.uptime(), 0


		test "path", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('path')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.resolve, 'function'
					assert.equal result.resolve('/abc'), Path.resolve('/abc')


		test "punycode", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('punycode')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.encode, 'function'
					assert.equal result.encode('例.com'), result.encode result.decode result.encode('例.com')


		test "querystring", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('querystring')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.encode, 'function'
					assert.equal result.encode('abc.com/simply-&-import'), require('querystring').encode('abc.com/simply-&-import')


		test "string_decoder", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('string_decoder')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.StringDecoder, 'function'
					assert.doesNotThrow ()-> new result.StringDecoder('utf8')


		test "stream", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('stream')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'function'
					assert.typeOf result.Readable, 'function'
					assert.doesNotThrow ()-> new result.Writable


		test "timers", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('timers')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.setImmediate, 'function'


		test "tty", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('tty')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.ReadStream, 'function'


		test "url", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('url')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.parse, 'function'
					require('assert').deepEqual result.parse('https://google.com'), require('url').parse('https://google.com')


		test "vm", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('vm')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.runInNewContext, 'function'
					# assert.deepEqual result.parse('https://google.com'), require('url').parse('https://google.com')


		test "zlib", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('zlib')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.createGzip, 'function'
					assert.doesNotThrow ()-> result.createGzip()


		test "crypto", ()->
			@timeout 5e4
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('crypto')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.createHmac, 'function'
					assert.equal result.createHmac('sha256','abc').update('s').digest('hex'), require('crypto').createHmac('sha256','abc').update('s').digest('hex')


		test "unshimmable core modules", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					"main.js": """
						exports.cluster = require('cluster')
						exports.dgram = require('dgram')
						exports.dns = require('dns')
						exports.fs = require('fs')
						exports.module = require('module')
						exports.net = require('net')
						exports.readline = require('readline')
						exports.repl = require('repl')
					"""
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.deepEqual result.cluster, {}
					assert.deepEqual result.dgram, {}
					assert.deepEqual result.dns, {}
					assert.deepEqual result.fs, {}
					assert.deepEqual result.module, {}
					assert.deepEqual result.net, {}
					assert.deepEqual result.readline, {}
					assert.deepEqual result.repl, {}



	suite "UMD bundles", ()->
		suiteSetup emptyTemp
		
		test "will not have their require statements scanned", ()->
			scanResults = raw:null, umd:null
			runtimeResults = raw:null, umd:null
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = import './a'
							exports.b = require('./b')
							exports.c = import './c'
						"""
						'a.js': "module.exports = 'abc'"
						'b.js': "module.exports = 'def'"
						'c.js': "module.exports = require('./c-hidden')"
						'c-hidden.js': "module.exports = 'jhi'"

				.then ()-> processAndRun file:temp('main.js'), umd:'main', usePaths:true
				.tap ({result})-> runtimeResults.raw = result
				.tap ({compiled})-> fs.writeAsync temp('umd.js'), compiled
				
				.then ()-> processAndRun file:temp('umd.js')
				.tap ({result})-> runtimeResults.umd = result
				
				.then ()-> SimplyImport.scan file:temp('main.js'), depth:Infinity
				.then (result)-> scanResults.raw = result
				
				.then ()-> SimplyImport.scan file:temp('umd.js'), depth:Infinity
				.then (result)-> scanResults.umd = result

				.then ()->
					assert.equal runtimeResults.raw.a, runtimeResults.umd.a
					assert.equal runtimeResults.raw.b, runtimeResults.umd.b
					assert.equal runtimeResults.raw.c, runtimeResults.umd.c
					assert.deepEqual scanResults.raw, [
						temp('a.js')
						temp('b.js')
						temp('c.js')
						temp('c-hidden.js')
					]
					assert.deepEqual scanResults.umd, []


		test "will have their require statements scanned if the require variable is never defined", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = require('module-a')
							exports.b = require('module-b')
							exports.c = require('module-c')
						"""
						'node_modules/prefix-a/index.js': """
							module.exports = 'module-';
						"""
						'node_modules/prefix-b/index.js': """
							module.exports = 'MODULE-';
						"""
						'node_modules/prefix-c/index.js': """
							module.exports = 'MoDuLe-';
						"""
						'node_modules/module-a/index.js': """
							module.exports = require('prefix-a')+'a';
						"""
						'node_modules/module-b/index.js': """
							if (typeof module !== 'undefined' && typeof exports !== 'undefined') {
								var thePrefix = require('prefix-b')
							}
							module.exports = thePrefix+'b';
						"""
						'node_modules/module-c/index.js': """
							(function(require){
								if (typeof module !== 'undefined' && typeof exports !== 'undefined') {
									var thePrefix = require('prefix-c')
								}
								module.exports = thePrefix+'c';
							})(function(){return 'noprefix-'})
						"""
				.then ()-> processAndRun file:temp('main.js'), usePaths:true
				.then ({result, compiled})->
					assert.equal result.a, 'module-a'
					assert.equal result.b, 'MODULE-b'
					assert.equal result.c, 'noprefix-c'
					assert.include compiled, "'module-'"
					assert.include compiled, "'MODULE-'"
					assert.notInclude compiled, "'MoDuLe-'"


		test "can be imported", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = import 'moment/moment.js'
							exports.b = import 'moment/src/moment.js'
						"""

				.then ()-> processAndRun file:temp('main.js'),usePaths:true
				.then ({result, writeToDisc})->
					now = Date.now()
					assert.notEqual result.a, result.b
					assert.typeOf result.a, 'function'
					assert.typeOf result.b, 'function'
					assert.equal result.a(now).subtract(1, 'hour').valueOf(), result.b(now).subtract(1, 'hour').valueOf()



	suite ".bin files", ()->
		suiteSetup ()->
			helpers.lib
				'main.js': """
					module.exports = import './.bin'
				"""
				'main.nobang.js': """
					module.exports = import './nobang.bin'
				"""
				'.bin': """
					#!/usr/bin/env node
					exports.a = import './a'
					exports.b = import './b'
				"""
				'nobang.bin': """
					exports.a = import './a'
					exports.b = import './b'
				"""
				'inline.bin': """
					#!/usr/bin/env node
					a = import './a-inline'
					b = import './b-inline'
				"""
				'a.js': "module.exports = require('a-inline')"
				'b.js': "module.exports = require('b-inline')"
				'a-inline.js': "'abc'"
				'b-inline.js': "'def'"
		

		test "can be imported", ()->
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.nobang.js')
				.then ({result, compiled})->
					assert.equal result.a, 'abc'
					assert.equal result.b, 'def'


		test "will have the shebang stripped when imported as module", ()->
			Promise.resolve()
				.then ()-> processAndRun temp('main.js')
				.then ({result, compiled})->
					assert.equal result.a, 'abc'
					assert.equal result.b, 'def'
					assert.notInclude compiled, '#!/usr/bin/env'


		test "will not have the shebang stripped when is entry file and only has inline imports", ()->
			Promise.resolve()
				.then ()-> SimplyImport file:temp('inline.bin')
				.tap (compiled)->
					assert.include compiled, '#!/usr/bin/env'
					assert.equal compiled.lines()[0], '#!/usr/bin/env node'

				.then (compiled)-> 
					compiled = compiled.lines().slice(1).join('\n')
					runCompiled 'inline.bin', compiled, context={}
			
					assert.equal context.a, 'abc'
					assert.equal context.b, 'def'


		test "will have its shebang moved to the top when is entry file", ()->
			Promise.resolve()
				.then ()-> SimplyImport temp('.bin')
				.tap (compiled)->
					assert.include compiled, '#!/usr/bin/env'
					assert.equal compiled.lines()[0], '#!/usr/bin/env node'
				
				.then (compiled)->
					compiled = compiled.lines().slice(1).join('\n')
					result = runCompiled '.bin', compiled, {}
					
					assert.equal result.a, 'abc'
					assert.equal result.b, 'def'


		test "will be picked up in scans", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js'), depth: Infinity
				.then (result)->
					result.sort()
					assert.deepEqual result, [
						temp('.bin')
						temp('a-inline.js')
						temp('a.js')
						temp('b-inline.js')
						temp('b.js')
					]



	suite "common modules", ()->
		test "axios", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('axios')"
				.then ()-> processAndRun file:temp('main.js'), null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
				.then ({result, writeToDisc})->
					assert.typeOf result, 'function'
					req = null; token = result.CancelToken.source();
					assert.doesNotThrow ()-> req = result.get('https://google.com', cancelToken:token.token)
					token.cancel('cancelled')
					
					Promise.resolve(req)
						.catch message:'cancelled', (err)->
	

		test "yo-yo", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('yo-yo')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'function'
	

		test "smart-extend", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('smart-extend')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'function'
					obj = {a:1, b:2, c:[3,4,5]}
					clone = result.clone.deep.concat obj
					clone2 = result.clone.deep.concat obj, c:[1,2,2]
					assert.notEqual obj, clone
					assert.deepEqual obj, clone
					assert.deepEqual clone2.c, [3,4,5,1,2,2]
	

		test "formatio", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('formatio')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.ascii, 'function'
	

		test "timeunits", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('timeunits')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert Object.keys(result).length > 1
	

		test "redux", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('redux')"
				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.createStore, 'function'
					store = result.createStore(->)
					assert.typeOf store.dispatch, 'function'
					assert Object.keys(result).length > 1


		test "lodash", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('lodash')"
				.then ()-> processAndRun file:temp('main.js'), usePaths:true
				.then ({result,writeToDisc})->
					writeToDisc()
					assert.typeOf result, 'function'
					assert.typeOf result.last, 'function'
					assert.equal result.last([1,2,3]), 3
					assert Object.keys(result).length > 1
	

		test "moment", ()->
			Promise.resolve()
				.then ()-> helpers.lib "main.js": "module.exports = require('moment/src/moment.js')"
				.then ()-> processAndRun file:temp('main.js'), usePaths:true, 'moment.js'
				.then ({result})->
					now = Date.now()
					assert.typeOf result, 'function'
					assert.equal (now - 3600000), result(now).subtract(1, 'hour').valueOf()
					assert Object.keys(result).length > 1



	suite "browserify compatibility", ()->
		suiteSetup ()->
			Streamify = require 'streamify-string'
			Browserify = require 'browserify'
			Browserify::bundleAsync = Promise.promisify(Browserify::bundle)
		

		test "packages that declare 'simplyimport/compat' transform will make the module compatibile", ()->
			compiled = null
			Promise.resolve()
				.then emptyTemp
				.then ()-> fs.symlinkAsync process.cwd(), temp('node_modules/simplyimport')
				.then ()->
					helpers.lib
						'node_modules/sm-module/main.js': """
							exports.a = import './a'
							exports.b = import './b $ nested.data'
							importInline './exportC'
							exports.d = (function(){
								return import './d'
							})()
							exports.other = import 'other-module'
						"""
						'node_modules/sm-module/a.js': """
							module.exports = 'abc-value';
						"""
						'node_modules/sm-module/b.json': """
							{"nested":{"data":"def-value"}}
						"""
						'node_modules/sm-module/c.yml': """
							nested:
                              data: 'gHi-value'
						"""
						'node_modules/sm-module/d.js': """
							export default jkl = 'jkl-value';
						"""
						'node_modules/sm-module/exportC.js': """
							exports.c = import 'c $ nested.data'
						"""
						'node_modules/sm-module/package.json': JSON.stringify
							main: 'index.js'
							browser: 'main.js'
							browserify: transform: [['simplyimport/compat', {'myOpts':true}]]
					
						'node_modules/other-module/package.json': JSON.stringify main:'index.js'
						'node_modules/other-module/index.js': "module.exports = 'abc123'"

				# .tap ()-> processAndRun(src:"module.exports = require('sm-module');", context:temp()).then(console.log).then ()-> process.exit()
				.then ()-> Browserify(Streamify("module.exports = require('sm-module');"), basedir:temp()).bundleAsync()
				# .tap (result)-> fs.writeAsync debug('browserify.js'), result
				.then (result)-> result.toString()
				.then (result)-> runCompiled('browserify.js', compiled=result, {})
				.then (result)->
					assert.typeOf result, 'function'
					assert.typeOf theModule=result(1), 'object'
					assert.equal theModule.a, 'abc-value'
					assert.equal theModule.b, 'def-value'
					assert.equal theModule.c, 'gHi-value'
					assert.equal theModule.d, 'jkl-value'
					assert.equal theModule.other, 'abc123'
					assert.include compiled, 'MODULE_NOT_FOUND'
		

		test "'simplyimport/compat' accepts a 'umd' option", ()->
			compiled = null
			Promise.resolve()
				.then emptyTemp
				.then ()-> fs.symlinkAsync process.cwd(), temp('node_modules/simplyimport')
				.then ()->
					helpers.lib
						'node_modules/sm-module/main.js': """
							exports.a = import './a'
							exports.b = import './b $ nested.data'
							exports.c = require('c $ nested.data')
							exports.d = (function(){
								return import './d'
							})()
							exports.other = import 'other-module'
						"""
						'node_modules/sm-module/a.js': """
							module.exports = 'abc-value';
						"""
						'node_modules/sm-module/b.json': """
							{"nested":{"data":"def-value"}}
						"""
						'node_modules/sm-module/c.yml': """
							nested:
                              data: 'gHi-value'
						"""
						'node_modules/sm-module/d.js': """
							export default jkl = 'jkl-value';
						"""
						'node_modules/sm-module/package.json': JSON.stringify
							main: 'index.js'
							browser: 'main.js'
							browserify: transform: [['simplyimport/compat', {'umd':'SMBundle'}]]
					
						'node_modules/other-module/package.json': JSON.stringify main:'index.js'
						'node_modules/other-module/index.js': "module.exports = 'abc123'"

				.then ()-> Browserify(Streamify("module.exports = require('sm-module');"), basedir:temp()).bundleAsync()
				.then (result)-> result.toString()
				.then (result)-> runCompiled('browserify.js', compiled=result, {})
				.then (result)->
					assert.typeOf result, 'function'
					assert.typeOf theModule=result(1), 'object'
					assert.equal theModule.a, 'abc-value'
					assert.equal theModule.b, 'def-value'
					assert.equal theModule.c, 'gHi-value'
					assert.equal theModule.d, 'jkl-value'
					assert.equal theModule.other, 'abc123'
					assert.include compiled, 'SMBundle'


		test "simplyimport bundles will skip 'simplyimport/compat'", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'package.json': JSON.stringify browserify:{transform:['simplyimport/compat','test/helpers/replacerTransform']}
						'main.js': """
							a = import 'module-a'
							b = import 'module-b'
							c = import './c'
							d = 'gHi'
						"""
						'c.js': """
							ghi = 'gHi-value'
						"""
					
						'node_modules/module-a/package.json': JSON.stringify browserify:{transform:[['simplyimport/compat', data:1], 'test/helpers/lowercaseTransform']}
						'node_modules/module-a/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-a/a.js': """
							result = 'gHi-VALUE'
						"""
					
						'node_modules/module-b/package.json': JSON.stringify browserify:{transform:[["test/helpers/replacerTransform", {someOpt:true}]]}
						'node_modules/module-b/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-b/a.js': """
							result = 'gHi-VALUE'
						"""
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a.a, 'ghi-value'
					assert.equal context.a.b, 'value-ghi'
					assert.equal context.b.a, 'GhI-VALUE'
					assert.equal context.b.b, 'vaLUe-GhI'
					assert.equal context.c, 'GhI-value'
					assert.equal context.d, 'GhI'



	suite "scan imports", ()->
		suiteSetup ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = import './a'
							exports.b = require('b')
							import './c'
							import d from './d'
							import * as e from './e'
							exports.f = import './f$version'
							exports.g = import './g $ nested.version'
							export * from 'nested'
						"""
						'main2.js': ['main.js', (content)-> content.replace "import './c'", "importInline './c'"]
						'main.cyclic.js': ['main.js', (content)-> content.replace "from './d'", "from './d2'"]
						'main.errors.js': ['main.js', (content)-> content.replace "from './d'", "from './d3'"]
						"main.conditionals.js": """
							import './a'

							// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
							require('b')
							// simplyimport:end

							// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
							import './c'
							// simplyimport:end

							import d from './d'

							// simplyimport:if VAR_A == 'gibberish'
							import * as e from './e'
							// simplyimport:end
						"""
						'main.emptyStubs.js': """
							exports.a = import './a'
							exports.b = import './b'
							exports.c = import './ccc-undefined'
							exports.d = import './d'
						"""
						'a.js': "import 'a2'"
						'a2.js': "module.exports = 'file a2.js'"
						'b.js': "module.exports = 'file b.js'"
						'c.js': "import 'c2'"
						'c2/index.coffee': "module.exports = do -> import './nested'"
						'c2/nested.coffee': "'file c2.coffee'"
						'd/index.js': "export default value = 'file d.js'"
						'd2/index.js': "export default value = require('./cyclic.js')"
						'd2/cyclic.js': "module.exports = require('../main.cyclic.js')"
						'd3/index.js': "export default value = require('./errors.js') + require('./noerrors.js')"
						'd3/errors.js': "module.exports = ()-> 1..2.2.3."
						'e.js': "var value='file e.js';\nexport {value}"
						'f.json': """
							{"version":"1.0.5"}
						"""
						'g.yaml': """
							nested:
							  version: 2.8.5
						"""
						'nested/_index.js': """
							exports.nestedA = require('./a.js ')
							exports.nestedB = import './b.js'
						"""
						'nested/a.js': "module.exports = 'file nested/a.js'"
						'nested/b.js': "module.exports = import './b2'"
						'nested/b2.js': "module.exports = 'file nested/b2.js'"


		test "basic flat scan (default)", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js')
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.notInclude result,	temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'c.js'
					assert.notInclude result,	temp 'c2/index.coffee'
					assert.notInclude result,	temp 'c2/nested.coffee'
					assert.include result,		temp 'd/index.js'
					assert.include result,		temp 'e.js'
					assert.include result,		temp 'f.json'
					assert.include result,		temp 'g.yaml'
					assert.include result,		temp 'nested/_index.js'
					assert.notInclude result,	temp 'nested/a.js'
					assert.notInclude result,	temp 'nested/b.js'
					assert.notInclude result,	temp 'nested/b2.js'


		test "scan depth can be controlled with options.depth", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js'), depth:1
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.include result,		temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'c.js'
					assert.include result,		temp 'c2/index.coffee'
					assert.notInclude result,	temp 'c2/nested.coffee'
					assert.include result,		temp 'd/index.js'
					assert.include result,		temp 'e.js'
					assert.include result,		temp 'f.json'
					assert.include result,		temp 'g.yaml'
					assert.include result,		temp 'nested/_index.js'
					assert.include result,		temp 'nested/a.js'
					assert.include result,		temp 'nested/b.js'
					assert.notInclude result,	temp 'nested/b2.js'


		test "importInline statements will ignore depth", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main2.js')
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.notInclude result,	temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'c.js'
					assert.include result,	temp 'c2/index.coffee'
					assert.notInclude result,	temp 'c2/nested.coffee'
					assert.include result,		temp 'd/index.js'
					assert.include result,		temp 'e.js'
					assert.include result,		temp 'f.json'
					assert.include result,		temp 'g.yaml'
					assert.include result,		temp 'nested/_index.js'
					assert.notInclude result,	temp 'nested/a.js'
					assert.notInclude result,	temp 'nested/b.js'
					assert.notInclude result,	temp 'nested/b2.js'


		test "paths will be relative when options.relativePaths is set", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js'), depth:1, relativePaths:true
				.then (result)->
					tempRel = ()-> Path.relative process.cwd(), temp(arguments...)
					
					assert Array.isArray(result)
					assert.include result,		tempRel 'a.js'
					assert.include result,		tempRel 'a2.js'
					assert.include result,		tempRel 'b.js'
					assert.include result,		tempRel 'c.js'
					assert.include result,		tempRel 'c2/index.coffee'
					assert.notInclude result,	tempRel 'c2/nested.coffee'
					assert.include result,		tempRel 'd/index.js'
					assert.include result,		tempRel 'e.js'
					assert.include result,		tempRel 'f.json'
					assert.include result,		tempRel 'g.yaml'
					assert.include result,		tempRel 'nested/_index.js'
					assert.include result,		tempRel 'nested/a.js'
					assert.include result,		tempRel 'nested/b.js'
					assert.notInclude result,	tempRel 'nested/b2.js'


		test "syntax errors and missing files will be ignored", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.errors.js'), depth:Infinity
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.include result,		temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'c.js'
					assert.include result,		temp 'c2/index.coffee'
					assert.include result,		temp 'c2/nested.coffee'
					assert.include result,		temp 'd3/index.js'
					assert.include result,		temp 'd3/errors.js'
					assert.include result,		temp 'e.js'
					assert.include result,		temp 'f.json'
					assert.include result,		temp 'g.yaml'
					assert.include result,		temp 'nested/_index.js'
					assert.include result,		temp 'nested/a.js'
					assert.include result,		temp 'nested/b.js'
					assert.include result,		temp 'nested/b2.js'


		test "nested scan (options.flat = false)", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js'), depth:Infinity, flat:false
				.then (result)->
					assert Array.isArray(result)
					assert.typeOf result[0], 'object'
					assert.deepEqual result, [
						file: temp('a.js')
						imports: [
							file: temp('a2.js')
							imports: []
						]
					,
						file: temp('b.js')
						imports: []
					,
						file: temp('c.js')
						imports: [
							file: temp('c2/index.coffee')
							imports: [
								file: temp('c2/nested.coffee')
								imports: []
							]
						]
					,
						file: temp('d/index.js')
						imports: []
					,
						file: temp('e.js')
						imports: []
					,
						file: temp('f.json')
						imports: []
					,
						file: temp('g.yaml')
						imports: []
					,
						file: temp('nested/_index.js')
						imports: [
							file: temp('nested/a.js')
							imports: []
						,
							file: temp('nested/b.js')
							imports: [
								file: temp('nested/b2.js')
								imports: []
							]
						]
					]


		test "nested scan with options.depth:0", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.js'), flat:false
				.then (result)->
					assert Array.isArray(result)
					assert.typeOf result[0], 'object'
					assert.deepEqual result, [
						file: temp('a.js')
						imports: []
					,
						file: temp('b.js')
						imports: []
					,
						file: temp('c.js')
						imports: []
					,
						file: temp('d/index.js')
						imports: []
					,
						file: temp('e.js')
						imports: []
					,
						file: temp('f.json')
						imports: []
					,
						file: temp('g.yaml')
						imports: []
					,
						file: temp('nested/_index.js')
						imports: []
					]


		test "cyclic refs will be excluded", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.cyclic.js'), depth:Infinity, flat:false
				.then (result)->
					# console.dir result, colors:true, depth:Infinity
					assert Array.isArray(result)
					assert.typeOf result[0], 'object'
					assert.deepEqual result, [
						file: temp('a.js')
						imports: [
							file: temp('a2.js')
							imports: []
						]
					,
						file: temp('b.js')
						imports: []
					,
						file: temp('c.js')
						imports: [
							file: temp('c2/index.coffee')
							imports: [
								file: temp('c2/nested.coffee')
								imports: []
							]
						]
					,
						file: temp('d2/index.js')
						imports: [
							file: temp('d2/cyclic.js')
							imports: []
						]
					,
						file: temp('e.js')
						imports: []
					,
						file: temp('f.json')
						imports: []
					,
						file: temp('g.yaml')
						imports: []
					,
						file: temp('nested/_index.js')
						imports: [
							file: temp('nested/a.js')
							imports: []
						,
							file: temp('nested/b.js')
							imports: [
								file: temp('nested/b2.js')
								imports: []
							]
						]
					]


		test "cyclic refs will be included when options.cyclic is set", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.cyclic.js'), depth:Infinity, flat:false, cyclic:true
				.then (result)->
					# console.dir result, colors:true, depth:Infinity
					assert Array.isArray(result)
					assert.typeOf result[0], 'object'
					assert.deepEqual result, [
						file: temp('a.js')
						imports: [
							file: temp('a2.js')
							imports: []
						]
					,
						file: temp('b.js')
						imports: []
					,
						file: temp('c.js')
						imports: [
							file: temp('c2/index.coffee')
							imports: [
								file: temp('c2/nested.coffee')
								imports: []
							]
						]
					,
						file: temp('d2/index.js')
						imports: [
							file: temp('d2/cyclic.js')
							imports: [
								file: temp('main.cyclic.js')
								imports: result
							]
						]
					,
						file: temp('e.js')
						imports: []
					,
						file: temp('f.json')
						imports: []
					,
						file: temp('g.yaml')
						imports: []
					,
						file: temp('nested/_index.js')
						imports: [
							file: temp('nested/a.js')
							imports: []
						,
							file: temp('nested/b.js')
							imports: [
								file: temp('nested/b2.js')
								imports: []
							]
						]
					]


		test "imports inside conditionals will be included", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.conditionals.js'), depth:Infinity
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.include result,		temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'c.js'
					assert.include result,		temp 'c2/index.coffee'
					assert.include result,		temp 'c2/nested.coffee'
					assert.include result,		temp 'd/index.js'
					assert.include result,		temp 'e.js'


		test "imports inside conditionals will not be included when options.matchAllConditions is false", ()->
			Promise.resolve()
				.then ()->
					process.env.VAR_A = 'abc'
					process.env.VAR_B = 'def'
				.then ()-> SimplyImport.scan file:temp('main.conditionals.js'), depth:Infinity, matchAllConditions:false
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.include result,		temp 'a2.js'
					assert.include result,		temp 'b.js'
					assert.notInclude result,	temp 'c.js'
					assert.notInclude result,	temp 'c2/index.coffee'
					assert.notInclude result,	temp 'c2/nested.coffee'
					assert.include result,		temp 'd/index.js'
					assert.notInclude result,	temp 'e.js'


		test "empty stubs will be removed in flat scans", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.emptyStubs.js')
				.then (result)->
					assert Array.isArray(result)
					assert.include result,		temp 'a.js'
					assert.include result,		temp 'b.js'
					assert.include result,		temp 'd/index.js'
					assert.notInclude result,	temp 'c.js'
					assert.notInclude result,	temp 'ccc-undefined.js'
					assert.notInclude result,	temp 'c2/index.coffee'
					assert.notInclude result,	require('../lib/constants').EMPTY_STUB


		test "empty stubs will be removed in nested scans", ()->
			Promise.resolve()
				.then ()-> SimplyImport.scan file:temp('main.emptyStubs.js'), flat:false, depth:Infinity
				.then (result)->
					assert Array.isArray(result)
					assert.deepEqual result, [
						file: temp('a.js')
						imports: [
							file: temp('a2.js')
							imports: []
						]
					,
						file: temp('b.js')
						imports: []
					,
						file: temp('d/index.js')
						imports: []
					]


		test "no duplicates", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'duplicates.js': """
							import './aaa'
							import './bbb'
							import './ccc'
						"""
						'aaa.js': "module.exports = import './bbb'"
						'bbb.js': "module.exports = import './ccc'"
						'ccc.js': "module.exports = import './aaa'"
				.then ()-> SimplyImport.scan file:temp('duplicates.js')
				.then (result)->
					assert Array.isArray(result)
					assert.equal result.length, 3
					assert.deepEqual result, [
						temp('aaa.js')
						temp('bbb.js')
						temp('ccc.js')
					]



	suite "sass", ()->
		test "imports will be inlined", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.sass': """
							.abc
								font-weight: 500
								color: black

							.def
								color: white
								@import './nested'

							@import "./ghi"
							@import './jkl'
						"""
						'ghi.sass': """
							.ghi
								opacity: 1
						"""
						'jkl.sass': """
							.jkl
								opacity: 0.5
						"""
						'nested/index.sass': """
							.def-child
								height: 300px
								importInline 'other'
						"""
						'nested/other.sass': """
							.other-child
								height: 400px
						"""

				.then ()-> SimplyImport file:temp('main.sass')
				.then (compiled)->
					assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
					assert.include compiled, '.def-child'
					assert.include compiled, 'height: 300px'
					assert.include compiled, '.other-child'
					assert.include compiled, 'height: 400px'
					assert.include compiled, '.ghi'
					assert.include compiled, 'opacity: 1'
					assert.include compiled, '.jkl'
					assert.include compiled, 'opacity: 0.5'

					css = null
					assert.doesNotThrow ()-> css = require('node-sass').renderSync(data:compiled, indentedSyntax:true).css.toString()
					Promise.resolve()
						.then ()-> require('modcss')(temp('main.css'), {})
						.then (stream)-> require('get-stream') require('streamify-string')(css).pipe(stream)
						.then (result)-> runCompiled('css.js', result, {module:{}})
						.then (tree)->
							assert.deepEqual tree,
								'.abc':
									fontWeight: '500'
									color: 'black'
								
								'.def':
									color: 'white'
								
								'.def .def-child':
									height: '300px'
								
								'.def .def-child .other-child':
									height: '400px'
								
								'.ghi':
									opacity: '1'
								
								'.jkl':
									opacity: '0.5'


	suite "pug/jade", ()->
		test "imports will be inlined", ()->
			Promise.resolve()
				.then emptyTemp
				.then ()->
					helpers.lib
						'main.pug': """
							html
								head
									include './meta'
									link(rel='stylesheet', href='/index.css')
									include './scripts'
								
								importInline './body'
						"""
						'meta/index.jade': """
							include './a'
							importInline './importB'
							include 'c'
						"""
						'meta/a.jade': """meta(name="content", value="a.jade")"""
						'meta/b.pug': """meta(name="content", value="b.pug")"""
						'meta/c.jade': """meta(name='content', value='c.jade')"""
						'meta/importB.pug': """include 'b'"""
						'scripts.pug': """
							script(src="/a.js")
							script(src="/b.js")
						"""
						'body.jade': """
							body
								main
									div
										span='firstSpan'
										span=include 'spanText'
										span='lastSpan'
						"""
						'spanText.pug': "'abc123'"

				.then ()-> SimplyImport file:temp('main.pug')
				.then (compiled)->
					assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
					assert.include compiled, 'meta(name="content", value="a.jade")'
					assert.include compiled, 'meta(name="content", value="b.pug")'
					assert.include compiled, "meta(name='content', value='c.jade')"
					assert.include compiled, 'script(src="/a.js")'
					assert.include compiled, "span='abc123'"
					assert.notInclude compiled, "spanText"
					
					html = null
					assert.doesNotThrow ()-> html = require('pug').render(compiled)
					tree = require('html2json').html2json(html)

					adjust = (node)->
						delete node.node if node.node isnt 'root'
						return if not node.child
						adjust(child) for child in node.child
						return
					
					adjust(tree)
					assert.deepEqual tree,
						node: 'root'
						child: [
							tag: 'html'
							child: [
								tag: 'head'
								child: [
									tag: 'meta'
									attr: {name:'content', value:'a.jade'}
								,
									tag: 'meta'
									attr: {name:'content', value:'b.pug'}
								,
									tag: 'meta'
									attr: {name:'content', value:'c.jade'}
								,
									tag: 'link'
									attr: {rel:'stylesheet', href:'/index.css'}
								,
									tag: 'script'
									attr: {src:'/a.js'}
									child: [text:'']
								,
									tag: 'script'
									attr: {src:'/b.js'}
									child: [text:'']
								]
							,
								tag: 'body'
								child: [
									tag: 'main'
									child: [
										tag: 'div'
										child: [
											tag: 'span'
											child: [text:'firstSpan']
										,
											tag: 'span'
											child: [text:'abc123']
										,
											tag: 'span'
											child: [text:'lastSpan']
										]
									]
								]
							]
						]


	suite "http imports", ()->
		suiteTeardown ()-> require('nock').restore()
		suiteSetup ()->
			@slow(1e4)
			mock = (host, path, reply...)->
				require('nock')(host).persist()
					.get(path).reply(reply...)
					.head(path).reply(reply...)
			
			Promise.resolve()
				.then ()-> fs.dir require('../lib/helpers/temp')(), empty:true
				.then ()->
					mock('https://example.com', '/a', 200, 'module.exports = "module-a"')
					mock('https://example.com', '/b', 200, 'module.exports = "module-b"')
					mock('https://example.com', '/c', 200, 'module.exports = {dir:__dirname, file:__filename}', etag:'abc123')
					mock('https://example.com', '/d.js', 200, 'module.exports = {dir:__dirname, file:__filename}')
					mock('https://example.com', '/e.json', 200, JSON.stringify main:'index.js', version:'1.2.3-alpha')
					mock('https://example.com', '/f', 301, '', 'location':'https://example.com/f2')
					mock('https://example.com', '/f2', 200, 'module.exports = "module-f"')
					mock('https://example.com', '/g', 403, 'unauthorized')
					mock('https://example.com', '/h', 500)
				.then ()->
					helpers.lib
						'someModuleA/entrypoint.js': """
							exports.a = import './childA'
							exports.b = import './childB'
							exports.dir = __dirname
							exports.file = __filename
						"""
						'someModuleA/childA.js': "module.exports = 'I am childA'"
						'someModuleA/childB.js': "module.exports = 'I am childB'"
						'someModuleA/childB.coffee': "module.exports = 'I am childB-coffee'"
						'someModuleA/package.json': JSON.stringify
							main: 'entrypoint.js'
							browser: './childB.js':'./childB.coffee'

				.then ()-> TarGZ.compress temp('someModuleA'), temp('someModuleA.tgz')
				.then ()-> fs.copyAsync temp('someModuleA.tgz'), temp('someModuleB.tgz')
				.then ()->
					mock('https://example.com', '/moduleA.tgz', 200, fs.read(temp('someModuleA.tgz'), 'buffer'), etag:'theFirstModule')
					mock('https://example.com', '/moduleB.tar.gz', 200, fs.read(temp('someModuleB.tgz'), 'buffer'), etag:'theSecondModule')


		test "js files can be downloaded and used as modules", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = import 'https://example.com/a'
							exports.b = require('https://example.com/b')
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.deepEqual result, a:'module-a', b:'module-b'


		test "downloads will be cached to temp folder when etag header exists", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.main = import 'https://example.com/c'
							exports.child = import './child'
						"""
						'child.js': """
							module.exports = import 'https://example.com/c'
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.deepEqual result.main, result.child
					assert.equal Path.resolve(result.main.dir), require('../lib/helpers/temp')()
					assert.equal Path.resolve(result.main.file), require('../lib/helpers/temp')()+'/abc123.js'


		test "downloads will be cached to temp folder when etag header does not exists", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							module.exports = import 'https://example.com/d.js'
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'object'
					assert.equal Path.resolve(result.dir), require('../lib/helpers/temp')()
					assert.include Path.resolve(result.file), require('../lib/helpers/temp')()


		test "non-js files can be downloaded", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							module.exports = import 'https://example.com/e.json $ version'
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.typeOf result, 'string'
					assert.equal result, '1.2.3-alpha'


		test "tarballs can be donwloaded and will be treated as packages", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.a = import 'https://example.com/moduleA.tgz'
							exports.b = import 'https://example.com/moduleB.tar.gz'
						"""

				.then ()-> processAndRun file:temp('main.js'), dedupe:false
				.then ({result})->
					assert.typeOf result, 'object'
					assert.typeOf result.a, 'object'
					assert.typeOf result.b, 'object'
					assert.equal result.a.a, 'I am childA'
					assert.equal result.b.a, 'I am childA'
					assert.equal result.a.b, 'I am childB-coffee'
					assert.equal result.b.b, 'I am childB-coffee'
					assert.equal Path.resolve(result.a.dir), require('../lib/helpers/temp')()+'/theFirstModule'
					assert.equal Path.resolve(result.a.file), require('../lib/helpers/temp')()+'/theFirstModule/entrypoint.js'
					assert.equal Path.resolve(result.b.dir), require('../lib/helpers/temp')()+'/theSecondModule'
					assert.equal Path.resolve(result.b.file), require('../lib/helpers/temp')()+'/theSecondModule/entrypoint.js'


		test "redirects will be followed", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							module.exports = import 'https://example.com/f'
						"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({result})->
					assert.equal result, 'module-f'


		test "error will be thrown on response statuses >= 400", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'403.js': """
							module.exports = import 'https://example.com/g'
						"""
						'500.js': """
							module.exports = import 'https://example.com/h'
						"""

				.then ()->
					Promise.resolve()
						.then ()-> SimplyImport file:temp('403.js')
						.then ()-> assert false
						.catch (err)-> assert.include err.message, 'failed to download https://example.com/g (403)'
						.then ()-> SimplyImport file:temp('500.js')
						.then ()-> assert false
						.catch (err)-> assert.include err.message, 'failed to download https://example.com/h (500)'


	suite.skip "source maps", ()->
		suiteSetup ()->
			@fileContents = {}
			Promise.resolve()
				.then ()-> helpers.lib
					'main.js': """
						exports.a = import './a'
						exports.version = import './package $ version'
						exports.b = require('./b')
						export * from './c'
						exports.d = importInline './d'
						exports.e = import 'module-e'
						exports.f = require('module-f')
						exports.g = require('module-g')
						exports.h = require('module-h')
					"""
					'main2.js': ['main.js', (content)-> "#{content}\nexports.h = require('module-h')"]
					'a.js': "module.exports = 'aaa';"
					'b.js': "export default 'bbb';"
					'c.js': "export var c1 = 'ccc1';\n\nexport var c2='ccc2'"
					'd.js': """
						'd'+ "d" +
						'd'
					"""
					'package.json': JSON.stringify {version:'1.2.9', name:'olee'}, 2
					'node_modules/module-e/package.json': JSON.stringify {main:'_index.coffee'}
					'node_modules/module-e/_index.coffee': """
						module.exports = 'module---' +
						'e'+ "e" +
						'e'
					"""
					'node_modules/module-f/package.json': JSON.stringify {main:'index.js'}
					'node_modules/module-f/index.js': """
						'module---' +
						'f' +  "f" +
						'f'
					"""
					'node_modules/module-g/package.json': JSON.stringify {main:'index.coffee'}
					'node_modules/module-g/index.coffee': """
						module.exports = ()-> "module---\#{('g' for i in [1..3]).join('')}"
					"""
					'node_modules/module-h/package.json': JSON.stringify {main:'index.coffee'}
					'node_modules/module-h/index.coffee': """
						true and "module---\#{'hhh'}"
					"""
					'node_modules/module-i/package.json': JSON.stringify {main:'index.coffee'}
					'node_modules/module-i/index.coffee': """
						module.exports = ()-> typeof process
					"""
				.then ()-> Promise.props {
					"#{temp 'main.js'}": fs.readAsync(temp 'main.js')
					"#{temp 'package.json'}": fs.readAsync(temp 'package.json')
					"#{temp 'a.js'}": fs.readAsync(temp 'a.js')
					"#{temp 'b.js'}": fs.readAsync(temp 'b.js')
					"#{temp 'c.js'}": fs.readAsync(temp 'c.js')
					"#{temp 'd.js'}": fs.readAsync(temp 'd.js')
					"#{temp 'node_modules/module-f/index.js'}": fs.readAsync(temp 'node_modules/module-f/index.js')
					"#{temp 'node_modules/module-e/_index.coffee'}": fs.readAsync(temp 'node_modules/module-e/_index.coffee').then(require('coffee-script').compile)
					"#{temp 'node_modules/module-g/index.coffee'}": fs.readAsync(temp 'node_modules/module-g/index.coffee').then(require('coffee-script').compile)
					"#{temp 'node_modules/module-h/index.coffee'}": fs.readAsync(temp 'node_modules/module-h/index.coffee').then(require('coffee-script').compile)
					"#{temp 'node_modules/module-i/index.coffee'}": fs.readAsync(temp 'node_modules/module-i/index.coffee').then(require('coffee-script').compile)
				}
				.then (result)=> @fileContents = result

		test "will be disabled by default", ()->
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, result})->
					assert.equal typeof result.g, 'function'
					result.g = result.g()
					assert.deepEqual result,
						a: 'aaa'
						b: 'bbb'
						c1: 'ccc1'
						c2: 'ccc2'
						d: 'ddd'
						e: 'module---eee'
						f: 'module---fff'
						g: 'module---ggg'
						h: 'module---hhh'
						version: '1.2.9'

					assert.notInclude compiled, '//# sourceMappingURL'


		test "will be enabled when options.sourceMap", ()->
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.js'), sourceMap:true
				.then ({compiled, result})->
					assert.equal typeof result.g, 'function'
					result.g = result.g()
					assert.deepEqual result,
						a: 'aaa'
						b: 'bbb'
						c1: 'ccc1'
						c2: 'ccc2'
						d: 'ddd'
						e: 'module---eee'
						f: 'module---fff'
						g: 'module---ggg'
						h: 'module---hhh'
						version: '1.2.9'

					assert.include compiled, '//# sourceMappingURL'


		test "will be enabled when options.debug", ()->
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.js'), debug:true
				.then ({compiled, result})->
					assert.include compiled, '//# sourceMappingURL'


		test "will be disabled when options.debug but not options.sourceMap", ()->
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.js'), debug:true, sourceMap:false
				.then ({compiled, result})->
					assert.notInclude compiled, '//# sourceMappingURL'


		test.skip "mappings", ()->
			fileContents = @fileContents
			chalk = require 'chalk'
			
			Promise.resolve()
				.then ()-> processAndRun file:temp('main.js'), sourceMap:true
				.tap ({compiled})-> fs.writeAsync debug('sourcemap.js'), compiled
				.then ({compiled, result})->
					sourceMap = require('convert-source-map').fromSource(compiled).sourcemap
					mappingsRaw = require('combine-source-map/lib/mappings-from-map')(sourceMap)
					mappings = Object.values mappingsRaw.groupBy(((map)-> map.name or map.source))
					mappings = (mappings.map (group)-> group.inGroupsOf(2)).flatten(1)
					compiledLines = stringPos(compiled)
					
					# console.dir mappingsRaw, colors:true, depth:4
					
					mappings.forEach ([start, end], index)->
						file = temp(start.source.replace('file://localhost/',''))
						source = fileContents[file]
						lines = stringPos(source)
						orig = start:stringPos.toIndex(source, start.original), end:stringPos.toIndex(source, end.original)
						gen = start:stringPos.toIndex(compiled, start.generated), end:stringPos.toIndex(compiled, end.generated)
						# debugStr = "mapping[#{index}] #{Path.relative(temp(), file)} "

						console.log '\n\n\n'+chalk.dim(Path.relative(temp(), file))
						# console.log chalk.yellow(source.slice(orig.start, orig.end))
						# console.log chalk.green(compiled.slice(gen.start, gen.end))
						require('@danielkalen/print-code')(source)
							.highlightRange(start.original, end.original)
							.slice(start.original.line-1, end.original.line+2)
							.color('green')
							.print()
						console.log '-'.repeat(Math.min process.stdout.columns, 20)
						require('@danielkalen/print-code')(compiled)
							.highlightRange(start.generated, end.generated)
							.slice(start.generated.line-1, end.generated.line+2)
							.color('red')
							.print()


	suite "path placeholders", ()->
		test "%CWD will resolve to the current working directory of the runner", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					"main.js": """
						aaa = import './a';
						bbb = import '%CWD/test/temp/b';
						ccc = import 'module-c';
					"""
					"a/index.js": """
						module.exports = require('%CWD/test/temp/a/nested/file');
					"""
					"a/nested/file.js": """
						module.exports = 'aaa';
					"""
					"b.js": """
						module.exports = 'bbb';
					"""
					"c.js": """
						module.exports = 'ccc';
					"""
					"node_modules/module-c/package.json": JSON.stringify main:'index.js'
					"node_modules/module-c/index.js": """
						module.exports = import './nested';
					"""
					"node_modules/module-c/nested/index.js": """
						module.exports = import '%CWD/test/temp/c';
					"""
					"node_modules/module-c/c.js": """
						module.exports = 'module-ccc';
					"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'ccc'


		test "%BASE will resolve to the dir of the entry file", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					"main.js": """
						aaa = import './a';
						bbb = import '%BASE/b';
						ccc = import 'module-c';
					"""
					"a/index.js": """
						module.exports = require('%BASE/a/nested/file');
					"""
					"a/nested/file.js": """
						module.exports = 'aaa';
					"""
					"b.js": """
						module.exports = 'bbb';
					"""
					"c.js": """
						module.exports = 'ccc';
					"""
					"node_modules/module-c/package.json": JSON.stringify main:'index.js'
					"node_modules/module-c/index.js": """
						module.exports = import './nested';
					"""
					"node_modules/module-c/nested/index.js": """
						module.exports = import '%BASE/c';
					"""
					"node_modules/module-c/c.js": """
						module.exports = 'module-ccc';
					"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'module-ccc'


		test "%ROOT will resolve to the dir of the package file", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					"package.json": JSON.stringify main:'main.js'
					"main.js": """
						aaa = import './a';
						bbb = import '%ROOT/b';
						ccc = import 'module-c';
					"""
					"a/index.js": """
						module.exports = require('%ROOT/a/nested/file');
					"""
					"a/nested/file.js": """
						module.exports = 'aaa';
					"""
					"b.js": """
						module.exports = 'bbb';
					"""
					"c.js": """
						module.exports = 'ccc';
					"""
					"node_modules/module-c/package.json": JSON.stringify main:'index.js'
					"node_modules/module-c/index.js": """
						module.exports = import './nested';
					"""
					"node_modules/module-c/nested/index.js": """
						module.exports = import '%ROOT/c';
					"""
					"node_modules/module-c/c.js": """
						module.exports = 'module-ccc';
					"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'module-ccc'


		test "custom placeholder can be defined in settings.placeholder and will be resolved relative to the package file", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					"package.json": JSON.stringify main:'main.js', simplyimport:placeholder:{'ABC':'../temp/', 'DEF':'secret'}
					"main.js": """
						aaa = import '%ABC/a';
						bbb = import '%DEF/b';
						ccc = import 'module-c';
					"""
					"a/index.js": """
						module.exports = require('%DEF/a/nested/file');
					"""
					"secret/a/nested/file.js": """
						module.exports = 'aaa';
					"""
					"secret/b.js": """
						module.exports = 'bbb';
					"""
					"secret/c.js": """
						module.exports = 'ccc';
					"""
					"node_modules/module-c/package.json": JSON.stringify main:'index.js', simplyimport:placeholder:{'GHI':'./supersecret'}
					"node_modules/module-c/index.js": """
						module.exports = import './nested';
					"""
					"node_modules/module-c/nested/index.js": """
						module.exports = import '%GHI/c';
					"""
					"node_modules/module-c/supersecret/c.js": """
						module.exports = import '%DEF/c';
					"""

				.then ()-> processAndRun file:temp('main.js')
				.then ({context})->
					assert.equal context.aaa, 'aaa'
					assert.equal context.bbb, 'bbb'
					assert.equal context.ccc, 'ccc'










