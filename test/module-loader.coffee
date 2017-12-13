helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers


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




