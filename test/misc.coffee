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









