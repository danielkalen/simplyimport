Path = require 'path'
fs = require 'fs-jetpack'
chalk = require 'chalk'
pos = require 'string-pos'
extend = require 'smart-extend'
getMappings = require 'combine-source-map/lib/mappings-from-map'
convertSourceMap = require 'convert-source-map'
helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, SimplyImport, emptyTemp, badES6Support} = helpers
{SourceMapConsumer} = require 'source-map'

suite "source maps", ()->
	suiteSetup ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'main.js': """
					exports.a = import './a'
					exports.version = import './package $ version'
					exports.b = require('./b')
					export * from './c'
					exports.d = importInline './d'
					exports.e = import 'module-e'
					exports.f = require('module-f')
					exports.g = require('module-g')
					exports.h = require('module-h')
				"""
				'a.js': "module.exports = 'aaa';"
				'b.js': "export default 'bbb';"
				'c.js': "export var c1 = 'ccc1';\n\nexport var c2='ccc2'"
				'd.js': """
					'd'+ "d" +
					'd'
				"""
				'package.json': JSON.stringify {version:'1.2.9', name:'olee'}, 2
				'node_modules/module-e/package.json': JSON.stringify {main:'_index.coffee'}
				'node_modules/module-e/_index.coffee': """
					module.exports = 'module---' +
					'e'+ "e" +
					'e'
				"""
				'node_modules/module-f/package.json': JSON.stringify {main:'index.js'}
				'node_modules/module-f/index.js': """
					'module---' +
					'f' +  "f" +
					'f'
				"""
				'node_modules/module-g/package.json': JSON.stringify {main:'index.coffee'}
				'node_modules/module-g/index.coffee': """
					module.exports = ()-> "module---\#{('g' for i in [1..3]).join('')}"
				"""
				'node_modules/module-h/package.json': JSON.stringify {main:'index.coffee'}
				'node_modules/module-h/index.coffee': """
					true and "module---\#{'hhh'}"
				"""
				'node_modules/module-i/package.json': JSON.stringify {main:'index.coffee'}
				'node_modules/module-i/index.coffee': """
					module.exports = ()-> typeof process
				"""
			.then ()-> Promise.props {
				"#{temp 'main.js'}": fs.readAsync(temp 'main.js')
				"#{temp 'package.json'}": fs.readAsync(temp 'package.json')
				"#{temp 'a.js'}": fs.readAsync(temp 'a.js')
				"#{temp 'b.js'}": fs.readAsync(temp 'b.js')
				"#{temp 'c.js'}": fs.readAsync(temp 'c.js')
				"#{temp 'd.js'}": fs.readAsync(temp 'd.js')
				"#{temp 'node_modules/module-f/index.js'}": fs.readAsync(temp 'node_modules/module-f/index.js')
				"#{temp 'node_modules/module-e/_index.coffee'}": fs.readAsync(temp 'node_modules/module-e/_index.coffee').then(require('coffee-script').compile)
				"#{temp 'node_modules/module-g/index.coffee'}": fs.readAsync(temp 'node_modules/module-g/index.coffee').then(require('coffee-script').compile)
				"#{temp 'node_modules/module-h/index.coffee'}": fs.readAsync(temp 'node_modules/module-h/index.coffee').then(require('coffee-script').compile)
				"#{temp 'node_modules/module-i/index.coffee'}": fs.readAsync(temp 'node_modules/module-i/index.coffee').then(require('coffee-script').compile)
			}
			.then (result)=> @fileContents = result

	test "will be disabled by default", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result})->
				assert.equal typeof result.g, 'function'
				result.g = result.g()
				assert.deepEqual result,
					a: 'aaa'
					b: 'bbb'
					c1: 'ccc1'
					c2: 'ccc2'
					d: 'ddd'
					e: 'module---eee'
					f: 'module---fff'
					g: 'module---ggg'
					h: 'module---hhh'
					version: '1.2.9'
				assert.notInclude compiled, '//# sourceMappingURL'


	test "will be enabled when options.sourceMap", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), sourceMap:true
			.then ({compiled, result})->
				assert.equal typeof result.g, 'function'
				result.g = result.g()
				assert.equal result.version, '1.2.9'
				assert.include compiled, '//# sourceMappingURL'


	test "will be enabled when options.debug", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), debug:true
			.then ({compiled, result})->
				assert.include compiled, '//# sourceMappingURL'


	test "will be disabled when options.debug but not options.sourceMap", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), debug:true, sourceMap:false
			.then ({compiled, result})->
				assert.notInclude compiled, '//# sourceMappingURL'

	test "will be generated separate from bundle file when not options.inlineMap", ()->
		Promise.resolve()
			.then ()-> SimplyImport file:temp('main.js'), debug:true, inlineMap:false
			.then (result)->
				assert.equal typeof result, 'object'
				assert.deepEqual Object.keys(result), ['code','map']
				assert.notInclude result.code, '//# sourceMappingURL'
				assert.equal typeof result.map, 'object'


	suite "mappings", ()->
		test "mixed", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					'mixed.js': """
						exports.a = import './a'
						exports.b = require('./b')
						export * from './c'
						exports.d = import './d'
						var e = import 'module-e'
						exports.version = import './package $ version'
						exports.e = e
						exports.f = require('module-f')
						exports.g = require('module-g')
					"""
				.then ()-> processAndRun file:temp('mixed.js'), debug:true, 'sourcemap-mixed.js'
				.then ({compiled, result, writeToDisc})->
					writeToDisc()
					sourcemap = convertSourceMap.fromSource(compiled).sourcemap
					consumer = new SourceMapConsumer sourcemap
					origPos = origPosFn(consumer)

					assert.deepEqual origPos(11,0),		line(1,0,'mixed.js')
					assert.deepEqual origPos(11,12),	line(1,12,'mixed.js')
					assert.deepEqual origPos(12,0),		line(2,0,'mixed.js')
					assert.deepEqual origPos(12,12),	line(2,12,'mixed.js')
					assert.deepEqual origPos(12,17),	line(2,12,'mixed.js')
					assert.deepEqual origPos(16,4),		line(3,0,'mixed.js')
					assert.deepEqual origPos(21,0),		line(4,0,'mixed.js')
					assert.deepEqual origPos(21,12),	line(1,0,'d.js')
					assert.deepEqual origPos(23,0),		line(5,0,'mixed.js')
					assert.deepEqual origPos(23,8),		line(5,8,'mixed.js')
					assert.deepEqual origPos(23,8),		line(5,8,'mixed.js')
					assert.deepEqual origPos(24,0),		line(6,0,'mixed.js')
					assert.deepEqual origPos(24,18),	line(1,0,'package.json')
					assert.deepEqual origPos(25,0),		line(7,0,'mixed.js')
					assert.deepEqual origPos(26,0),		line(8,0,'mixed.js')
					assert.deepEqual origPos(26,12),	line(1,0,'node_modules/module-f/index.js')
					assert.deepEqual origPos(29,0),		line(9,0,'mixed.js')
					assert.deepEqual origPos(33,0),		line(1,0,'a.js')
					assert.deepEqual origPos(37,0),		line(1,0,'b.js')
					assert.deepEqual origPos(37,18),	line(1,15,'b.js')
					assert.deepEqual origPos(42,0),		line(1,0,'node_modules/module-e/_index.coffee')
					assert.deepEqual origPos(42,31),	line(2,0,'node_modules/module-e/_index.coffee')
					assert.deepEqual origPos(42,38),	line(2,5,'node_modules/module-e/_index.coffee')
					assert.deepEqual origPos(51,5),		line(1,48,'node_modules/module-g/index.coffee')
					assert.deepEqual origPos(55,6),		line(1,56,'node_modules/module-g/index.coffee')
		

		test "force inlines", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					'inlines.js': """
						exports.a = import './a'
						exports.b = importInline './b'
						exports.c = 'c'
						exports.d = importInline './d'
						exports.e = 'e'
						exports.version = importInline './package $ version'
						exports.f = require('module-f')
						exports.g = require('module-g')
					"""
					'b.js': """
						function(a,b){
							return a+b
						}
					"""
				.then ()-> processAndRun file:temp('inlines.js'), debug:true, 'sourcemap-inlines.js'
				.then ({compiled, result, writeToDisc})->
					writeToDisc()
					sourcemap = convertSourceMap.fromSource(compiled).sourcemap
					consumer = new SourceMapConsumer sourcemap
					origPos = origPosFn(consumer)

					assert.deepEqual origPos(11,0),		line(1,0,'inlines.js')
					assert.deepEqual origPos(11,12),	line(1,12,'inlines.js')
					assert.deepEqual origPos(12,0),		line(2,0,'inlines.js')
					assert.deepEqual origPos(12,12),	line(1,0,'b.js')
					assert.deepEqual origPos(12,22),	line(1,9,'b.js')
					assert.deepEqual origPos(13,7),		line(2,8,'b.js')
					assert.deepEqual origPos(15,0),		line(3,0,'inlines.js')
					assert.deepEqual origPos(15,12),	line(3,12,'inlines.js')
					assert.deepEqual origPos(16,0),		line(4,0,'inlines.js')
					assert.deepEqual origPos(16,12),	line(1,0,'d.js')
					assert.deepEqual origPos(16,18),	line(1,5,'d.js')
					assert.deepEqual origPos(16,24),	line(2,0,'d.js')
					assert.deepEqual origPos(17,0),		line(5,0,'inlines.js')
					assert.deepEqual origPos(17,12),	line(5,12,'inlines.js')
					assert.deepEqual origPos(18,0),		line(6,0,'inlines.js')
					assert.deepEqual origPos(18,18),	line(1,0,'package.json')
					assert.deepEqual origPos(19,0),		line(7,0,'inlines.js')
					assert.deepEqual origPos(19,12),	line(1,0,'node_modules/module-f/index.js')
					assert.deepEqual origPos(22,0),		line(8,0,'inlines.js')
					assert.deepEqual origPos(22,8),		line(8,8,'inlines.js')
					assert.deepEqual origPos(22,12),	line(8,12,'inlines.js')


		test "conditionals", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					'conditionals.js': """
						exports.a = import './a'
						// simplyimport:if VAR_A
						exports.b = importInline './b'
						// simplyimport:end
						exports.c = 'c'
						exports.d = importInline './d'
						exports.e = 'e'
						exports.version = importInline './package $ version'
						// simplyimport:if VAR_B
						exports.f = require('module-f')
						// simplyimport:end
						exports.g = require('module-g')
					"""
					'b.js': """
						function(a,b){
							return a+b
						}
					"""
				.then ()-> process.env.VAR_A = 1; delete process.env.VAR_B
				.then ()-> processAndRun file:temp('conditionals.js'), debug:true, 'sourcemap-conditionals.js'
				.then ({compiled, result, writeToDisc})->
					writeToDisc()
					sourcemap = convertSourceMap.fromSource(compiled).sourcemap
					consumer = new SourceMapConsumer sourcemap
					origPos = origPosFn(consumer)

					assert.deepEqual origPos(11,0),		line(1,0,'conditionals.js')
					assert.deepEqual origPos(11,12),	line(1,12,'conditionals.js')
					assert.deepEqual origPos(12,0),		line(2,0,'conditionals.js')
					assert.deepEqual origPos(12,12),	line(1,0,'b.js')
					assert.deepEqual origPos(12,22),	line(1,9,'b.js')
					assert.deepEqual origPos(13,7),		line(2,8,'b.js')
					assert.deepEqual origPos(15,0),		line(3,0,'conditionals.js')
					assert.deepEqual origPos(15,12),	line(3,12,'conditionals.js')
					assert.deepEqual origPos(16,0),		line(4,0,'conditionals.js')
					assert.deepEqual origPos(16,12),	line(1,0,'d.js')
					assert.deepEqual origPos(16,18),	line(1,5,'d.js')
					assert.deepEqual origPos(16,24),	line(2,0,'d.js')
					assert.deepEqual origPos(17,0),		line(5,0,'conditionals.js')
					assert.deepEqual origPos(17,12),	line(5,12,'conditionals.js')
					assert.deepEqual origPos(18,0),		line(6,0,'conditionals.js')
					assert.deepEqual origPos(18,18),	line(1,0,'package.json')
					assert.deepEqual origPos(19,0),		line(7,0,'conditionals.js')
					assert.deepEqual origPos(19,8),		line(7,8,'conditionals.js')
					assert.deepEqual origPos(19,12),	line(7,12,'conditionals.js')


		test.skip "mods", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					'mods.js': """
						exports.a = import './a'
						exports.browser = process.browser
						exports.b = importInline './b'
						exports.c = import './c'
						exports.d1 = import './d'
						exports.d2 = import './d'
					"""
					'b.js': """
						function(a,b){
							return a+b
						}
					"""
					'c.js': """
						module.exports = function(arg){
							return Buffer.from(arg)
						}
					"""
					'd.js': """
						var abc,def;
						abc = 123
						def = 456
					"""
				.then ()-> process.env.VAR_A = 1; delete process.env.VAR_B
				.then ()-> processAndRun file:temp('mods.js'), debug:true, usePaths:true, 'sourcemap-mods.js'
				.then ({compiled, result, writeToDisc})->
					writeToDisc()
					sourcemap = convertSourceMap.fromSource(compiled).sourcemap
					consumer = new SourceMapConsumer sourcemap
					origPos = origPosFn(consumer)

					assert.deepEqual origPos(12,0),		line(1,0,'mods.js')
					assert.deepEqual origPos(12,12),	line(1,12,'mods.js')
					assert.deepEqual origPos(13,0),		line(2,0,'mods.js')
					assert.deepEqual origPos(14,0),		line(3,0,'mods.js')
					assert.deepEqual origPos(14,12),	line(1,0,'b.js')
					assert.deepEqual origPos(14,22),	line(1,9,'b.js')
					assert.deepEqual origPos(14,7),		line(2,8,'b.js')
					assert.deepEqual origPos(18,0),		line(4,0,'mods.js')
					assert.deepEqual origPos(18,12),	line(4,12,'mods.js')
					assert.deepEqual origPos(19,0),		line(5,0,'mods.js')
					assert.deepEqual origPos(20,0),		line(6,0,'mods.js')
					
					assert.deepEqual origPos(189,0),	line(1,0,'c.js')
					assert.deepEqual origPos(190,7),	line(2,7,'c.js')
					



log = (object, depth=15)->
	console.dir object, {depth, colors:true}

line = (line, column, source)->
	{line, column, source}

origPosFn = (consumer)-> ()->
	extend.keys(['source','line','column']).clone(
		consumer.originalPositionFor(line(arguments...))
	)




