helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

suite "es6 imports", ()->
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
					'a.js': "module.exports.abc = 123"
					'b.js': "module.exports = 456"
					'c.js': "export default 789"
					'd.js': "exports.default = 111"
					'e.js': "exports['default'] = 222"

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.deepEqual result.a1, abc:123
				assert.deepEqual result.a2, abc:123
				assert.equal result.b1, 456
				assert.equal result.b2, 456
				assert.equal result.c1, 789
				assert.equal result.c2, 789
				assert.equal result.d1, 111
				assert.equal result.d2, 111
				assert.equal result.e1, 222
				assert.equal result.e2, 222









