Path = require 'path'
fs = require 'fs-jetpack'
chalk = require 'chalk'
pos = require 'string-pos'
extend = require 'smart-extend'
getMappings = require 'combine-source-map/lib/mappings-from-map'
convertSourceMap = require 'convert-source-map'
printCode = require '@danielkalen/print-code'
helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers
{SourceMapConsumer} = require 'source-map'

suite "source maps", ()->
	suiteSetup ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'simple.js': """
					exports.a = import './a'
					exports.b = require('./b')
					export * from './c'
					exports.d = import './d'
					var e = import 'module-e'
					exports.version = import './package $ version'
					exports.e = e
					exports.f = require('module-f')
				"""
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
				'main2.js': ['main.js', (content)-> "#{content}\nexports.h = require('module-h')"]
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


	test.only "mappings", ()->
		fileContents = @fileContents
		
		Promise.resolve()
			.then ()-> processAndRun file:temp('simple.js'), sourceMap:true
			.tap ({compiled})-> fs.writeAsync debug('sourcemap.js'), compiled
			.then ({compiled, result})->
				sourcemap = convertSourceMap.fromSource(compiled).sourcemap
				consumer = new SourceMapConsumer sourcemap
				origPos = origPosFn(consumer)

				# console.dir getMappings(sourcemap).slice(5,31), colors:1, depth:2
				# console.log getMappings(sourcemap).length
				assert.deepEqual origPos(11,0),		line(1,0,'simple.js')
				assert.deepEqual origPos(11,12),	line(1,12,'simple.js')
				assert.deepEqual origPos(12,0),		line(2,0,'simple.js')
				assert.deepEqual origPos(12,12),	line(2,12,'simple.js')
				assert.deepEqual origPos(12,17),	line(2,12,'simple.js')
				assert.deepEqual origPos(16,4),		line(3,0,'simple.js')
				assert.deepEqual origPos(21,0),		line(4,0,'simple.js')
				assert.deepEqual origPos(21,12),	line(4,12,'simple.js')
				assert.deepEqual origPos(23,0),		line(5,0,'simple.js')
				assert.deepEqual origPos(23,8),		line(5,8,'simple.js')
				# assert.deepEqual origPos(21,0),		line(2,12,'simple.js')
				
	

	test.skip "mappings", ()->
		fileContents = @fileContents
		
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), sourceMap:true
			.tap ({compiled})-> fs.writeAsync debug('sourcemap.js'), compiled
			.then ({compiled, result})->
				sourceMap = convertSourceMap.fromSource(compiled).sourcemap
				mappingsRaw = getMappings(sourceMap)
				mappings = Object.values mappingsRaw.groupBy(((map)-> map.name or map.source))
				mappings = (mappings.map (group)-> group.inGroupsOf(2)).flatten(1)
				compiledLines = pos(compiled)
				
				console.dir mappingsRaw, colors:true, depth:1
				# console.dir mappings, colors:true, depth:4
				# return
				
				mappings.forEach ([start, end], index)->
					file = temp(start.source.replace('file://localhost/',''))
					source = fileContents[file]
					orig = start:pos.toIndex(source, start.original), end:pos.toIndex(source, end.original)
					gen = start:pos.toIndex(compiled, start.generated), end:pos.toIndex(compiled, end.generated)
					# debugStr = "mapping[#{index}] #{Path.relative(temp(), file)} "

					console.log '\n\n\n'+chalk.dim(Path.relative(temp(), file))
					console.log chalk.yellow(source.slice(orig.start, orig.end))
					console.log chalk.green(compiled.slice(gen.start, gen.end))
					# printCode(source)
					# 	.highlightRange(start.original, end.original)
					# 	.slice(start.original.line-1, end.original.line+2)
					# 	.color('green')
					# 	.print()
					# console.log '-'.repeat(Math.min process.stdout.columns, 20)
					# printCode(compiled)
					# 	.highlightRange(start.generated, end.generated)
					# 	.slice(start.generated.line-1, end.generated.line+2)
					# 	.color('red')
					# 	.print()



line = (line, column, source)->
	{line, column, source}

origPosFn = (consumer)-> ()->
	extend.keys(['source','line','column']).clone(
		consumer.originalPositionFor(line(arguments...))
	)




