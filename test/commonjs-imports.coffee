helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

suite "commonJS", ()->
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


