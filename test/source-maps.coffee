helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite.skip "source maps", ()->
	suiteSetup ()->
		@fileContents = {}
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


	test.skip "mappings", ()->
		fileContents = @fileContents
		chalk = require 'chalk'
		stringPos = require 'string-pos'
		
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), sourceMap:true
			.tap ({compiled})-> fs.writeAsync debug('sourcemap.js'), compiled
			.then ({compiled, result})->
				sourceMap = require('convert-source-map').fromSource(compiled).sourcemap
				mappingsRaw = require('combine-source-map/lib/mappings-from-map')(sourceMap)
				mappings = Object.values mappingsRaw.groupBy(((map)-> map.name or map.source))
				mappings = (mappings.map (group)-> group.inGroupsOf(2)).flatten(1)
				compiledLines = stringPos(compiled)
				
				# console.dir mappingsRaw, colors:true, depth:4
				
				mappings.forEach ([start, end], index)->
					file = temp(start.source.replace('file://localhost/',''))
					source = fileContents[file]
					lines = stringPos(source)
					orig = start:stringPos.toIndex(source, start.original), end:stringPos.toIndex(source, end.original)
					gen = start:stringPos.toIndex(compiled, start.generated), end:stringPos.toIndex(compiled, end.generated)
					# debugStr = "mapping[#{index}] #{Path.relative(temp(), file)} "

					console.log '\n\n\n'+chalk.dim(Path.relative(temp(), file))
					# console.log chalk.yellow(source.slice(orig.start, orig.end))
					# console.log chalk.green(compiled.slice(gen.start, gen.end))
					require('@danielkalen/print-code')(source)
						.highlightRange(start.original, end.original)
						.slice(start.original.line-1, end.original.line+2)
						.color('green')
						.print()
					console.log '-'.repeat(Math.min process.stdout.columns, 20)
					require('@danielkalen/print-code')(compiled)
						.highlightRange(start.generated, end.generated)
						.slice(start.generated.line-1, end.generated.line+2)
						.color('red')
						.print()









