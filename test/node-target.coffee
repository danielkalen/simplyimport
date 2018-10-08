helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

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
					processAndRun {file:temp('main.js'), usePaths:true, target:'browser'}, undefined, {Buffer}
					processAndRun {file:temp('main.js'), usePaths:true, target:'node'}, undefined, {Buffer}
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
					processAndRun {file:temp('main.js'), usePaths:true, target:'browser'}, undefined, {require}
					processAndRun {file:temp('main.js'), usePaths:true, target:'node'}, undefined, {require}
				]

			.then ([browser, node])->
				assert.notEqual browser.compiled, node.compiled
				assert.typeOf browser.result.os, 'object'
				assert.typeOf node.result.os, 'object'
				assert.notDeepEqual browser.result.os, node.result.os
				assert.equal node.result.os, require('os')
				assert.equal node.result.fs, require('fs')










