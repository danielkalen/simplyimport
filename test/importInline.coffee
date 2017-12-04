helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "importInline statements", ()->
	test "would cause the contents of the import to be inlined prior to transformations & import/export collection", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'mainA.js': """
						switch (input) {
							case 'main':
								output = 'main'; break;
							import 'abc'
							import 'def'
							import 'ghi'
						}
					"""
					'mainB.js': """
						switch (input) {
							case 'main':
								output = 'main'; break;
							importInline 'abc'
							importInline 'def'
							importInline 'ghi'
						}
						import './jkl'
					"""
					'abc.js': """
						case 'abc':
							output = 'abc'; break;
					"""
					'def.js': """
						case 'def':
							output = 'def'; break;
					"""
					'ghi.js': """
						case 'ghi':
							output = 'ghi'; break;
					"""
					'jkl.coffee': """
						class jkl
							constructor: ()-> @bigName = 'JKL'
							importInline './jkl-methods'
					"""
					'jkl-methods.coffee': """
						getName: ()->
							return @bigName
						
						setName: ()->
							@bigName = arguments[0]
					"""

			.then ()-> SimplyImport file:temp('mainA.js')
			.catch ()-> 'failed as expected'
			.then (result)-> assert.equal result, 'failed as expected'
			.then ()-> processAndRun file:temp('mainB.js'), 'mainB.js', {input:'abc'}
			.then ({compiled, result, context, run})->
				assert.equal context.output, 'abc'
				context.input = 'ghi'
				run()
				assert.equal context.output, 'ghi'
				assert.equal typeof context.jkl, 'function'
				instance = new context.jkl
				assert.equal instance.getName(), 'JKL'
				instance.setName('another name')
				assert.equal instance.getName(), 'another name'
	

	test "will not be turned into separate modules if imported more than once", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'mainA.js': """
						abc = import './abc'
						def = import './abc'
						import './ghi'
						ghi = import './ghi'
					"""
					'mainB.js': """
						abc = importInline './abc'
						def = importInline './abc'
						importInline './ghi'
						ghi = importInline './ghi'
					"""
					'abc.js': """
						'abc123'
					"""
					'ghi.js': """
						theGhi = 'ghi789'
					"""

			.then ()->
				Promise.all [
					processAndRun file:temp('mainA.js')
					processAndRun file:temp('mainB.js')
				]
			.spread (bundleA, bundleB)->
				assert.notEqual bundleA.compiled, bundleB.compiled
				assert.include bundleA.compiled, 'require ='
				assert.notInclude bundleB.compiled, 'require ='
				assert.deepEqual bundleA.context, bundleB.context

				context = bundleB.context
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'abc123'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'


	test "will have their imports resolved relative to themselves", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						importInline './exportA'
						exports.a = import './a'
						exports.b = import './b $ nested.data'
						importInline './exportC'
						exports.d = (function(){
							return import './d'
						})()
						importInline './exportE'
						exports.other = import 'other.js'
					"""
					'a.js': """
						module.exports = 'abc-value';
					"""
					'a1.js': """
						module.exports = 'ABC-value';
					"""
					'a2.js': """
						module.exports = 'AbC-value';
					"""
					'b.json': """
						{"nested":{"data":"def-value"}}
					"""
					'c.yml': """
						nested:
                          data: 'gHi-value'
					"""
					'd.js': """
						export default jkl = 'jkl-value';
					"""
					'exportA.js': """
						exports.a1 = import 'a1'
						exports.a2 = import 'a2'
					"""
					'exportC.js': """
						exports.c = import 'c $ nested.data'
					"""
					'exportE/index.js': """
						exports.eA = importInline './eA'
						exports.e = import './e'
					"""
					'exportE/eA.js': """
						'Lorem ipsum dolor sit amet, consectetur adipiscing elit.\
						Cras nec malesuada lacus.\
						Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.'
					"""
					'exportE/e/index.js': """
						import './actual $ nested.data'
					"""
					'exportE/e/actual.json': ['b.json', (c)-> c]
					'other.js': """
						export default lmn = 'lmn-value';
					"""

			.then ()-> processAndRun file:temp('main.js'), 'main.js'
			.then ({compiled, result})->
				assert.equal result.a, 'abc-value'
				assert.equal result.a1, 'ABC-value'
				assert.equal result.a2, 'AbC-value'
				assert.equal result.b, 'def-value'
				assert.equal result.c, 'gHi-value'
				assert.equal result.d, 'jkl-value'
				assert.equal result.other, 'lmn-value'









