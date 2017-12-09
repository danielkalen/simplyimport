helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

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


test.only "inline imports will be wrapped in paranthesis when the import statement is part of a member expression", ()->
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
			assert.include compiled, 'require("./b")'


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


test.skip "es6 exports will be transpiled to commonJS exports", ()->
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
					var load = function(){
						import * as a from './a'
						import * as b from './b'
						return {a:a, b:b}
					}
					module.exports = load()
				"""
				'a.js': """
					export var abc = 123;

					export default function(){
						import {def, ghi} from './a2'
						exports.def = def;
						exports.ghi = ghi;
					}
				"""
				'b.coffee': """
					export abc = 123
					export abc2 = 123
					export load = ()->
						exports.def = 456
						exports.ghi = import './b2'
						exports.jkl = 999
				"""
				'a2.js': "export var def = 456, ghi = 789"
				'b2.js': "export default 789"
				
		.then ()-> processAndRun file:temp('main.js'), usePaths:true
		.then ({compiled, result, writeToDisc})->
			assert.equal result.a.abc, 123
			assert.equal result.a.def, undefined
			assert.equal typeof result.a.default, 'function'
			result.a.default()
			assert.equal result.a.def, 456
			assert.equal result.a.ghi, 789

			assert.equal result.b.abc, 123
			assert.equal result.b.def, undefined
			assert.equal typeof result.b.load, 'function'
			result.b.load()
			assert.equal result.b.def, 456
			assert.equal result.b.ghi, 789
			assert.equal result.b.jkl, 999


test "imports/exports should be live", ()->
	Promise.resolve()
		.then emptyTemp
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
		.then ()-> processAndRun file:temp('main.js'), usePaths:true
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

		.then ()-> processAndRun file:temp('main.js'), usePaths:true
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










