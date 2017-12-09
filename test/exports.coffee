helpers = require './helpers'
extend = require 'smart-extend'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers


suite "es6 exports will be transpiled to commonJS exports", ()->
	suiteSetup emptyTemp
	
	test "named export", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'named.js': """
					export var aaa = 111;
					
					export let bbb = 222
					export const ccc = 333, ddd= 444,eee = 555
					export function add(a,b) {
						return a+b
					}
					export var sub = function(a,b) {
						return a-b
					}
				"""

			.then ()-> processAndRun file:temp('named.js')
			.then ({result})->
				values = extend.keys(['aaa','bbb','ccc','ddd','eee']).clone(result)
				expect(values).to.eql aaa:111, bbb:222, ccc:333, ddd:444, eee:555
				expect(result.add(2,6)).to.equal 8
				expect(result.sub(2,6)).to.equal -4


	test "named list export", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'named-list.js': """
					var aaa = 111, bbb = 222, ccc = 333;
					export {aaa,bbb as BBB, ccc, add}
					export var ddd = 444;
					
					function add(a,b) {
						return a+b
					}
				"""

			.then ()-> processAndRun file:temp('named-list.js')
			.then ({result})->
				values = extend.keys(['aaa','BBB','ccc','ddd']).clone(result)
				expect(values).to.eql aaa:111, BBB:222, ccc:333, ddd:444
				expect(result.add(2,6)).to.equal 8


	test "all export", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'all.js': """
					export * from './a'
					export * from './b.js'
					export * from 'c'
					export {d1, d2 as D2} from './d'
				"""
				'a.js': "export var aaa = 111"
				'b.js': "module.exports.bbb = 222"
				'c.js': "exports.ccc = 333"
				'd.js': "export var d1 = 123, d2 = 456"

			.then ()-> processAndRun file:temp('all.js'), usePaths:true
			.then ({result})->
				values = extend.keys(['aaa','bbb','ccc']).clone(result)
				expect(values).to.eql aaa:111, bbb:222, ccc:333
				expect(result.d1).to.equal 123
				expect(result.D2).to.equal 456


	test "default export", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'default.js': """
					import * as aaa from './a'
					import * as bbb from './b'
					import * as ccc from './c'
					import * as ddd from './d'
					export {aaa,bbb,ccc,ddd}
				"""
				'a.js': "export default aaa = 111"
				'b.js': """
					var bbb = 222
					export {bbb}
					export default bbb
				"""
				'c.js': """
					export default function (a,b){return a+b}
					export function ccc(a,b) {return a-b}
				"""
				'd.js': """
					export default class DDD {
						constructor(name) {
							this.name = name;
						}
					}
				"""

			.then ()-> processAndRun file:temp('default.js'), usePaths:true
			.then ({result})->
				values = extend.keys(['aaa','bbb','ccc','ddd']).clone(result)
				expect(values.aaa).to.eql default:111
				expect(values.bbb).to.eql default:222, bbb:222
				expect(values.ccc.ccc(9,4)).to.equal 5
				expect(values.ccc.default(9,4)).to.equal 13
				expect(values.ddd.default.name).to.equal 'DDD'
				inst = new values.ddd.default('ddd')
				expect(inst.name).to.equal 'ddd'


	test "mixed es5/es6", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'mixed.js': """
					export var aaa = 111;
					exports.bbb = 222
					module.exports.ccc = 333
					export let add = (a,b)=> a+b					
				"""

			.then ()-> processAndRun file:temp('mixed.js')
			.then ({result})->
				values = extend.keys(['aaa','bbb','ccc']).clone(result)
				expect(values).to.eql aaa:111, bbb:222, ccc:333
				expect(result.add(2,6)).to.equal 8


	test "mixed es5/es6", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'mixed.js': """
					export var aaa = 111;
					exports.bbb = 222
					module.exports.ccc = 333
					export let add = (a,b)=> a+b					
				"""

			.then ()-> processAndRun file:temp('mixed.js')
			.then ({result})->
				values = extend.keys(['aaa','bbb','ccc']).clone(result)
				expect(values).to.eql aaa:111, bbb:222, ccc:333
				expect(result.add(2,6)).to.equal 8


	test "misc", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'misc.js': """
					export * from './child'
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
				'child.js': """
					export class Child {
						constructor(name) {
							this.name = name;
						}
					}
				"""

			.then ()-> processAndRun file:temp('misc.js')
			.then ({result})->
				assert.equal result.default, 'maybe'
				assert.equal result.ABC, 'ABC'
				assert.deepEqual result.def, {a:[1,2,3]}
				assert.deepEqual result.DEF, ['DEF', {a:[1,2,3]}]
				assert.equal result.ghi(), null
				assert.equal result.oi, undefined
				assert.equal result.GHI, 'GHI'
				assert.equal result.jkl, false
				assert.equal result.Child.name, 'Child'
				inst = new result.Child('theChild')
				assert.equal inst.name, 'theChild'


