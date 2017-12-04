helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

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










