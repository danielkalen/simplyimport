helpers = require './helpers'
{assert, expect, temp, runCompiled, processAndRun, SimplyImport} = helpers

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










