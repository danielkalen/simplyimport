helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

suite "exclusion", ()->
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






