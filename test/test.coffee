global.Promise = require 'bluebird'
fs = require 'fs-jetpack'
Path = require 'path'
mocha = require 'mocha'
vm = require 'vm'
assert = require('chai').assert
expect = require('chai').expect
helpers = require './helpers'
nodeVersion = parseFloat(process.version[1])
badES6Support = nodeVersion < 6
bin = Path.resolve 'bin'
SimplyImport = require '../'

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


processAndRun = (opts, filename='script.js', context={})->
	SimplyImport(opts).then (compiled)->
		debugPath = debug(filename)
		writeToDisc = ()-> fs.writeAsync(debugPath, compiled).timeout(500)
		run = ()-> (new vm.Script(compiled, {filename})).runInNewContext(context)
		
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


	test "importInline statements would cause the contents of the import to be inlined prior to transformations & import/export collection", ()->
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

			.then ()-> SimplyImport file:temp('mainA.js')
			.catch ()-> 'failed as expected'
			.then (result)-> assert.equal result, 'failed as expected'
			.then ()-> processAndRun file:temp('mainB.js'), 'mainB.js', {input:'abc'}
			.then ({compiled, result, context, run})->
				assert.equal context.output, 'abc'
				context.input = 'ghi'
				run()
				assert.equal context.output, 'ghi'
	

	test "importInline statements will not be turned into separate modules if imported more than once", ()->
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
			.then ()-> fs.dirAsync(temp(), empty:true)
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
			.then ()-> fs.dirAsync(temp(), empty:true)
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
			.then ()->
				helpers.lib
					'main.js': """
						aaa = import 'a'
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
						export default abc = 'abc'
						export {abc}
						exports.def = 456
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
						export var fff = 'fFf'
					"""
					'nested/f2.js': """
						export default function(a,b){return a+b}
						export var abc = 123
						export {jkl as jkl_, JKL} from 'f4'

						module.exports.def = 456
						export var def = 456, ghi = 789
					"""
					'nested/f3.js': """
						export var GHI = 'GHI'
					"""
					'nested/f4.js': """
						var a = 1, b = 2, jKl = 'jKl'
						export var jkl = 'jkl', JKL='JKL'
						export {a, jKl as default, b}
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
				# assert.equal result.h1,
				# assert.equal result.h2,
				# assert.equal result.f,


	test "es6 imports/exports can be placed in nested scopes", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							load = function(){
								import a from './a'
								import * as b from './b'
								import * as c from './c'
								return {a:a, b:b, c:c}
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
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, result, writeToDisc})->
					assert.deepEqual result.a, {abc:123, def:456, ghi:789, jkl:999}
					assert.deepEqual result.b, {__esModule:true, abc:123, def:456, ghi:789, jkl:999}
					assert.deepEqual result.c, {__esModule:true, abc:123}


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
					assert.deepEqual result.a, {__esModule:true, abc:'abc', def:'DEF'}
					assert.equal result.a, result.b
					assert.equal result.a, result.c


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
							module.exports = typeof global === 'undefined' ? ghi.toUpperCase() : 'GHI'
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
				assert.deepEqual bundleA.result, bundleA.context
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

			.then ()-> processAndRun file:temp('nested/main.js')
			.then ({compiled, result, context})->
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
						'package.json': '{"main":"entry.js", "simplyimport:specific":{"c.js":{"transform":"test/helpers/uppercaseTransform"}}}'
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					assert.equal context.a, 'abc-value'
					assert.equal context.b, 'def-value'
					assert.equal context.c, 'GHI-VALUE'


		test "transforms specified in package.json's browserify.transform field will be applied to imports of that package", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'package.json': '{"browserify":{"transform":"test/helpers/replacerTransform"}}'
						'main.js': """
							a = import 'module-a'
							b = import 'module-b'
							c = import './c'
							d = 'gHi'
						"""
						'c.js': """
							ghi = 'gHi-value'
						"""
					
						'node_modules/module-a/package.json': '{"browserify":{"transform":"test/helpers/lowercaseTransform"}}'
						'node_modules/module-a/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-a/a.js': """
							result = 'gHi-VALUE'
						"""
					
						'node_modules/module-b/package.json': '{"browserify":{"transform":"test/helpers/replacerTransform"}}'
						'node_modules/module-b/index.js': """
							exports.a = import './a'
							exports.b = 'vaLUe-gHi'
						"""
						'node_modules/module-b/a.js': """
							result = 'gHi-VALUE'
						"""
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					writeToDisc()
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


		test "coffeescript files will be automatically transformed by default", ()->
			Promise.resolve()
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


		test.skip "typescript files will be automatically transformed by default", ()->
			Promise.resolve()
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
						'c2.ts': "{'a':'def-value', 'b':'ghi-value'}"
						
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
				
				.then ()-> processAndRun file:temp('main.js')
				.then ({context, compiled, writeToDisc})->
					writeToDisc()
					assert.equal context.a, 'abc-value'
					assert.equal context.b.a, 'def-value'
					assert.equal context.b.b, 'ghi-value'
					assert.equal context.c.a, 'def-value'
					assert.equal context.c.b, 'ghi-value'
					assert.equal context.d.a, 'maybe'
					assert.equal context.d.b, 'inner-value'



	suite "extraction", ()->
		suiteSetup ()-> fs.dirAsync temp(), empty:true
		
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
					writeToDisc()
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
				.catch (err)-> assert.include(err.message, '^'); 'failed as expected'
				.then (result)-> assert.equal result, 'failed as expected'


		test "data can be extracted from cson files", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.cson $ dataPointA.simply import.abc[1]'
							b = require('a.cson $ dataPointA[13-seep].def[0]')
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
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.notInclude compiled, 'abc123'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}


		test "data can be extracted from yml files", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							a = import './a.yml $ dataPointA.simply import.abc[1]'
							b = require('a.yml $ dataPointA[13-seep].def[0]')
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
				.then ()-> processAndRun file:temp('main.js')
				.then ({compiled, context, writeToDisc})->
					assert.include compiled, 'require ='
					assert.notInclude compiled, 'dataPointB'
					assert.notInclude compiled, 'abc123'
					assert.typeOf context.a, 'object'
					assert.typeOf context.b, 'object'
					assert.deepEqual context.a, {"ABC":456}
					assert.deepEqual context.b, {"DEF":123}












