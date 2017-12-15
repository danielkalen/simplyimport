Path = require 'path'
fs = require 'fs-jetpack'
helpers = require './helpers'
{assert, expect, temp, processAndRun, emptyTemp, SimplyImport, nodeVersion} = helpers

suite "transforms", ()->
	test "provided through-stream transform functions will be passed each file's content prior to import/export scanning", ()->
		through = require('through2')
		customTransform = (file)->
			return through() if file.endsWith('b.js') or file.endsWith('main.js')
			through(
				(chunk, enc, done)->
					@push chunk.toString().toUpperCase()
					done()
				(done)->
					@push "\nmodule.exports = GHI+'-'+(require('./d'))" if file.endsWith('c.js')
					done()
			)

		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
					"""
					'a.js': """
						abc = 'abc-value'
					"""
					'b.js': """
						module.exports = 'def-value'
					"""
					'c.js': """
						ghi = 'ghi-value'
					"""
					'd.js': """
						jkl = 'jkl-value'
					"""
			.then ()-> processAndRun file:temp('main.js'), transform:[customTransform]
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'ABC-VALUE'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'GHI-VALUE-JKL-VALUE'
				assert.notInclude compiled, 'abc-value'


	test "strings resembling the transform file path can be provided in place of a function", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
					"""
					'a.js': """
						abc = 'abc-value'
					"""
					'b.js': """
						module.exports = 'def-value'
					"""
					'c.js': """
						ghi = 'ghi-value'
					"""
			.then ()-> processAndRun file:temp('main.js'), transform:['test/helpers/uppercaseTransform'], specific:{'b.js':{skipTransform:true}, 'main.js':{skipTransform:true}}
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'ABC-VALUE'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'GHI-VALUE'
				assert.notInclude compiled, 'abc-value'


	test "strings resembling the transform module name can be provided in place of a function", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
					"""
					'a.js': """
						abc = 'abc-value'
					"""
					'b.js': """
						module.exports = 'def-value'
					"""
					'c.js': """
						ghi = 'ghi-value'
					"""
					'package.json': '{"main":"entry.js"}'
					'node_modules/uppercase/index.coffee': fs.read './test/helpers/uppercaseTransform.coffee'
			
			.then ()-> processAndRun file:temp('main.js'), transform:['uppercase'], specific:{'b.js':{skipTransform:true}, 'main.js':{skipTransform:true}}
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'ABC-VALUE'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'GHI-VALUE'
				assert.notInclude compiled, 'abc-value'


	test "transforms specified in options.specific will be applied only to the specified file", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
					"""
					'a.js': """
						abc = 'abc-value'
					"""
					'b.js': """
						module.exports = 'def-value'
					"""
					'c.js': """
						ghi = 'ghi-value'
					"""
					'package.json': '{"main":"entry.js", "simplyimport":{"specific":{"c.js":{"transform":"test/helpers/uppercaseTransform"}}}}'
			
			.then ()-> processAndRun file:temp('main.js')
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'abc-value'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'GHI-VALUE'


	test "transforms specified in package.json's browserify.transform field will be applied to imports of that package", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'package.json': JSON.stringify browserify:{transform:'test/helpers/replacerTransform'}
					'main.js': """
						a = import 'module-a'
						b = import 'module-b'
						c = import './c'
						d = 'gHi'
					"""
					'c.js': """
						ghi = 'gHi-value'
					"""
				
					'node_modules/module-a/package.json': JSON.stringify browserify:{transform:['test/helpers/lowercaseTransform']}
					'node_modules/module-a/index.js': """
						exports.a = import './a'
						exports.b = 'vaLUe-gHi'
					"""
					'node_modules/module-a/a.js': """
						result = 'gHi-VALUE'
					"""
				
					'node_modules/module-b/package.json': JSON.stringify browserify:{transform:[["test/helpers/replacerTransform", {someOpt:true}]]}
					'node_modules/module-b/index.js': """
						exports.a = import './a'
						exports.b = 'vaLUe-gHi'
					"""
					'node_modules/module-b/a.js': """
						result = 'gHi-VALUE'
					"""
			
			.then ()-> processAndRun file:temp('main.js')
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a.a, 'ghi-value'
				assert.equal context.a.b, 'value-ghi'
				assert.equal context.b.a, 'GhI-VALUE'
				assert.equal context.b.b, 'vaLUe-GhI'
				assert.equal context.c, 'GhI-value'
				assert.equal context.d, 'GhI'


	test "global transforms will be applied to all processed files", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						A = import './a'
						b = import './b'
						C = import './c'
						d = import 'mODULe-A'
					"""
					'a.js': """
						abc = 'abc-VALUE'
					"""
					'b.js': """
						module.exports = 'DEF-value'
					"""
					'c.js': """
						GHI = 'ghi-VALUE'
					"""
					'node_modules/module-a/index.js': """
						exports.a = imPORt './a'
						exports.b = 'vaLUe-gHi'
					"""
					'node_modules/module-a/a.js': """
						result = 'gHi-VALUE'
					"""
			
			.then ()-> processAndRun file:temp('main.js'), globalTransform:[helpers.lowercaseTransform]
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'abc-value'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'ghi-value'
				assert.equal context.d.a, 'ghi-value'
				assert.equal context.d.b, 'value-ghi'
				assert.equal context.A, undefined


	test "final transforms will be applied to the final bundled file", ()->
		receivedFiles = []
		receivedContent = []
		customTransform = (file)->
			receivedFiles.push(file)
			return (content)->
				receivedContent.push(result=content.toLowerCase())
				return result

		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						A = import './a'
						b = import './b'
						C = import './c'
						d = import 'module-a'
					"""
					'a.js': """
						abc = 'abc-VALUE'
					"""
					'b.js': """
						module.exports = 'DEF-value'
					"""
					'c.js': """
						GHI = 'ghi-VALUE'
					"""
					'node_modules/module-a/index.js': """
						exports.a = import './a'
						exports.b = 'vaLUe-gHi'
					"""
					'node_modules/module-a/a.js': """
						result = 'gHi-VALUE'
					"""
			
			.then ()-> processAndRun file:temp('main.js'), finalTransform:[customTransform]
			.then ({context, compiled, writeToDisc})->
				assert.deepEqual receivedFiles, [temp('main.js')]
				assert.equal receivedContent.length, 1
				assert.equal receivedContent[0], compiled
				assert.equal context.a, 'abc-value'
				assert.equal context.b, 'def-value'
				assert.equal context.c, 'ghi-value'
				assert.equal context.d.a, 'ghi-value'
				assert.equal context.d.b, 'value-ghi'
				assert.equal context.A, undefined


	test "transforms specified in package.json will be applied", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': "module.exports = import './child'"
					'child.js': "module.exports = 'gHi'"
					'external.js': "module.exports = import 'module'"
					'node_modules/module/index.js': "module.exports = 'gHi'"
					'node_modules/module/package.json': JSON.stringify simplyimport:{transform:'test/helpers/replacerTransform'}
			
			.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{transform:'test/helpers/replacerTransform'}
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})-> assert.equal result, 'GhI'
			
			.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{globalTransform:'test/helpers/replacerTransform'}
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})-> assert.equal result, 'GhI'
			
			.then ()-> helpers.lib 'package.json': JSON.stringify simplyimport:{finalTransform:'test/helpers/replacerTransform'}
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})-> assert.equal result, 'GhI'
			
			.then ()-> processAndRun file:temp('main.js'), noPkgConfig:true
			.then ({result})-> assert.equal result, 'gHi'
			
			.then ()-> processAndRun file:temp('main.js'), noPkgConfig:true, transform:'test/helpers/replacerTransform'
			.then ({result})-> assert.equal result, 'GhI'
			
			.then ()-> helpers.lib 'package.json': JSON.stringify main:'index.js'
			.then ()-> processAndRun file:temp('external.js')
			.then ({result})-> assert.equal result, 'GhI'


	test "transforms will receive the file's full path as the 1st argument", ()->
		received = null
		customTransform = (file)->
			received = file
			require('through2')()

		Promise.resolve()
			.then ()->
				helpers.lib
					'abc.js': "'abc-value'"
					'deff/index.js': "'def-value'"
			
			.then ()-> assert.equal received, null
			.then ()-> SimplyImport src:"import './abc'", context:temp(), transform:customTransform
			.then ()-> assert.equal received, temp('abc.js')
			.then ()-> SimplyImport src:"import 'deff'", context:temp(), transform:customTransform
			.then ()-> assert.equal received, temp('deff/index.js')


	test "transforms will receive the tasks's options object as the 2nd argument under the _flags property", ()->
		received = null
		customTransform = (file, opts)->
			received = opts
			require('through2')()

		Promise.resolve()
			.then ()->
				helpers.lib
					'abc.js': "'abc-value'"
					'def/index.js': "'def-value'"
			
			.then ()-> assert.equal received, null
			.then ()-> SimplyImport src:"import './abc'", context:temp(), transform:customTransform
			.then ()->
				assert.typeOf received, 'object'
				assert.typeOf received._flags, 'object'
				assert.equal received._flags.src, "import './abc'"
				assert.equal received._flags.transform[0], customTransform


	test "transforms will receive the file's internal object as the 3rd argument", ()->
		received = null
		customTransform = (file, opts, file_)->
			received = file_
			require('through2')()

		Promise.resolve()
			.then ()->
				helpers.lib
					'deff/index.js': "'def-value'"
			
			.then ()-> assert.equal received, null
			.then ()-> SimplyImport src:"import './deff'", context:temp(), transform:customTransform
			.then ()->
				assert.typeOf received, 'object'
				assert.equal received.pathAbs, temp('deff/index.js')
				assert.equal received.path, Path.relative process.cwd(), temp('deff/index.js')
				assert.equal received.pathExt, 'js'
				assert.equal received.pathBase, 'index.js'
				assert.equal received.content, "'def-value'"


	test "transforms will receive the file's content as the 4rd argument", ()->
		received = null
		target = null
		customTransform = (file, opts, file_, content)->
			received = content if file is target
			require('through2')()

		Promise.resolve()
			.then ()->
				helpers.lib
					'abcc/index.js': "module.exports = 'def-value'"
					'deff/index.js': "import '../abcc'"
			
			.then ()-> assert.equal received, null
			.then ()-> target = temp('abcc/index.js')
			.then ()-> SimplyImport src:"importInline './abcc'", context:temp(), transform:customTransform
			.then ()-> assert.equal received, null
			.then ()-> SimplyImport src:"import './abcc'", context:temp(), transform:customTransform
			.then ()-> assert.equal received, "module.exports = 'def-value'"
			
			.then ()-> target = temp('deff/index.js')
			.then ()-> SimplyImport src:"import './deff'", context:temp(), transform:customTransform
			.then ()-> assert.equal received, "_$sm('../abcc' )"


	test "transforms can return a string", ()->
		customTransform = (file, o, d, content)->
			content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"

		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.first = import './abc'
						exports.second = import './deff'
						exports.third = import './ghi'
					"""
					'abc.js': "'abc-value'"
					'deff/index.js': "'def-value'"
					'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
			
			.then ()-> processAndRun file:temp('main.js'), transform:customTransform
			.then ({result})->
				assert.equal result.first, 'ABC---value'
				assert.equal result.second, 'DEF---value'
				assert.equal result.third, 'GHI---value___JKL---value'


	test "transforms can return a function which will be invoked with the file's content", ()->
		customTransform = (file)->
			assert.include file, temp()
			return (content)->
				content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"

		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.first = import './abc'
						exports.second = import './deff'
						exports.third = import './ghi'
					"""
					'abc.js': "'abc-value'"
					'deff/index.js': "'def-value'"
					'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
			
			.then ()-> processAndRun file:temp('main.js'), transform:customTransform
			.then ({result})->
				assert.equal result.first, 'ABC---value'
				assert.equal result.second, 'DEF---value'
				assert.equal result.third, 'GHI---value___JKL---value'


	test "transforms can return a promise who's value will be followed (function or string)", ()->
		customTransformA = (file, o, d, content)->
			Promise.resolve()
				.delay(10)
				.then ()-> content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"
				.delay(5)
		
		customTransformB = (file)->
			Promise.resolve()
				.delay(10)
				.then -> (content)-> content.replace /(...)-value/g, (e,word)-> "#{word.toUpperCase()}---value"
				.delay(5)

		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.first = import './abc'
						exports.second = import './deff'
						exports.third = import './ghi'
					"""
					'abc.js': "'abc-value'"
					'deff/index.js': "'def-value'"
					'ghi.js': "module.exports = 'ghi-value'+'___jkl-value'"
			
			.then ()->
				Promise.all [
					processAndRun file:temp('main.js'), transform:customTransformA
					processAndRun file:temp('main.js'), transform:customTransformB
				]
			.then ([moduleA, moduleB])->
				assert.equal moduleA.result.first, 'ABC---value'
				assert.equal moduleA.result.second, 'DEF---value'
				assert.equal moduleA.result.third, 'GHI---value___JKL---value'
				assert.deepEqual moduleA.result, moduleB.result


	test "coffeescript files will be automatically transformed by default", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
						d = import 'module-a'
					"""
					'a.coffee': """
						do ()-> abc = 'abc-value'
					"""
					'b/index.coffee': """
						module.exports = do ()-> abc = 456; require '../c'
					"""
					'c.coffee': """
						module.exports = importInline './c2'
					"""
					'c2.coffee': "'DEF-value'"
					
					'node_modules/module-a/package.json': '{"main":"./index.coffee"}'
					'node_modules/module-a/index.coffee': """
						module.exports.a = false or 'maybe'
						import {output as innerModule} from './inner'
						module.exports.b = innerModule
					"""
					'node_modules/module-a/inner.js': """
						var mainOutput = (function(){return 'inner-value'})()
						var otherOutput = 'another-value'
						export {mainOutput as output, otherOutput}
					"""
			
			.then ()-> processAndRun file:temp('main.js')
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'abc-value'
				assert.equal context.abc, undefined
				assert.equal context.b, 'DEF-value'
				assert.equal context.c, 'DEF-value'
				assert.equal context.d.a, 'maybe'
				assert.equal context.d.b, 'inner-value'


	test "typescript files will be automatically transformed by default", ()->
		Promise.resolve()
			.then ()-> fs.dir temp(), empty:true
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = import './b'
						c = import './c'
						d = import 'module-a'
					"""
					'a.ts': """
						function returner(label: string) {return label+'-value'}
						export = returner('abc');
					"""
					'b/index.ts': """
						function exporter(obj?: {a:string, b:string}) {
							import * as result from '../c'
							return result;
						}
						var result = exporter()
						export = result
					"""
					'c.ts': """
						export = importInline './c2'
					"""
					'c2.ts': "add = {'a':'def-value', 'b':'ghi-value'}"
					
					'node_modules/module-a/package.json': '{"main":"./index.ts"}'
					'node_modules/module-a/index.ts': """
						function extract(): string {
							return 'maybe';
						}
						export var a = extract()
						import {output as innerModule} from './inner'
						export var b = innerModule;
					"""
					'node_modules/module-a/inner.js': """
						var mainOutput = (function(){return 'inner-value'})()
						var otherOutput = 'another-value'
						export {mainOutput as output, otherOutput}
					"""
			
			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({context, compiled, writeToDisc})->
				assert.equal context.a, 'abc-value'
				assert.equal context.b.a, 'def-value'
				assert.equal context.b.b, 'ghi-value'
				assert.equal context.c.a, 'def-value'
				assert.equal context.c.b, 'ghi-value'
				assert.equal context.d.a, 'maybe'
				assert.equal context.d.b, 'inner-value'


	test "cson files will be automatically transformed by default", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.cson'
						b = require('b')
						b2 = import './b'
					"""
					'a.cson': """
						dataA:
							abc123: 1
							def456: 2
					"""
					'b/index.cson': """
						dataB: [
							4
							0
							1
						]
						dataB2: 123
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.include compiled, 'require ='
				assert.deepEqual context.a, {dataA: {abc123:1, def456:2}}
				assert.deepEqual context.b, {dataB:[4,0,1], dataB2:123}


	test "yml files will be automatically transformed by default", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = require('b')
						b2 = import './b'
					"""
					'a.yml': """
						dataA:
						  abc123: 1
						  def456: 2
					"""
					'b/index.yml': """
						dataB:
						  - 4
						  - 0
						  - 1
						dataB2: 123
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.include compiled, 'require ='
				assert.deepEqual context.a, {dataA: {abc123:1, def456:2}}
				assert.deepEqual context.b, {dataB:[4,0,1], dataB2:123}


	test "transforms named in options.ignoreTransform will be skipped", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = 'abc-value'
						b = 'def-value'
					"""
					'package.json': '{"main":"entry.js"}'
					'node_modules/abc-replacer/index.js': """
						module.exports = function(a,b,c,content){
							return content.replace(/abc-value/g, 'ABC---value')
						}
					"""
					'node_modules/def-replacer/index.js': """
						module.exports = function(a,b,c,content){
							return content.replace(/def-value/g, 'DEF---value')
						}
					"""
			.then ()->
				Promise.all [
					processAndRun file:temp('main.js'), transform:['abc-replacer', 'def-replacer']
					processAndRun file:temp('main.js'), transform:['abc-replacer', 'def-replacer'], ignoreTransform:['abc-replacer']
				]
			.then ([bundleA, bundleB])->
				assert.notEqual bundleA.compiled, bundleB.compiled
				assert.equal bundleA.context.a, 'ABC---value'
				assert.equal bundleA.context.b, 'DEF---value'
				assert.equal bundleB.context.a, 'abc-value'
				assert.equal bundleB.context.b, 'DEF---value'


	suite "popular transforms", ()-> # testing some real-world scenarios
		test "envify", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.main = process.env.VAR1
							if (process.env.VAR2 === 'chocolate') {
								a = import 'module-a'
							} 
							b = require('module-b')
						"""
						'node_modules/module-a/index.js': """
							module.exports = JSON.parse(process.env.VAR3)
						"""
						'node_modules/module-b/index.js': """
							process.env.VAR4
						"""
				.then ()->
					process.env.VAR1 = 'the main file'
					process.env.VAR2 = 'chocolate'
					process.env.VAR3 = '{"a":10, "b":20, "c":30}'
					process.env.VAR4 = 'the last env var'
					processAndRun file:temp('main.js'), transform:'envify', specific: 'module-a':{transform:['envify']},'module-b':{transform:['envify']}
				
				.then ({result, context, writeToDisc})->
					assert.equal result.main, 'the main file'
					assert.deepEqual context.a, {a:10,b:20,c:30}
					assert.equal context.b, 'the last env var'
	
		test "envify+options.env", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							exports.main = process.env.VAR1
							if (process.env.VAR2 === 'chocolate') {
								a = import 'module-a'
							} 
							b = require('module-b')
						"""
						'node_modules/module-a/index.js': """
							module.exports = JSON.parse(process.env.VAR3)
						"""
						'node_modules/module-b/index.js': """
							process.env.VAR4
						"""
						"customEnv": """
							VAR1=the main file
							VAR2=chocolate
							VAR3={"a":10, "b":20, "c":30}
						"""
				.then ()->
					delete process.env.VAR1
					delete process.env.VAR2
					delete process.env.VAR3
					delete process.env.VAR4
					process.env.VAR4 = 'the last env var'
					processAndRun file:temp('main.js'), globalTransform:'envify', env:temp('customEnv')
				
				.then ({result, context, writeToDisc})->
					assert.equal result.main, 'the main file'
					assert.deepEqual context.a, {a:10,b:20,c:30}
					assert.equal context.b, 'the last env var'
	

		test "brfs", ()->
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							main = require('fs').readFileSync(__dirname+'/first.html', 'utf8')
							a = import './a'
							b = import './b'
							c = b.toUpperCase()
						"""
						'a.js': """
							module.exports = require('fs').readFileSync(__dirname+'/second.html', 'utf8')
						"""
						'b.js': """
							require('fs').readFileSync(__dirname+'/third.html', 'utf8')
						"""
						'first.html': "<p>beep boop</p>"
						'second.html': "<div class=\"wrapper\">\n<p>beep boop</p>\n</div>"
						'third.html': "<div id='superWrapper'>\n<div class=\"wrapper\">\n<p>beep boop</p>\n</div>\n</div>"
				.then ()-> processAndRun file:temp('main.js'), transform:'brfs'
				.then ({context, writeToDisc})->
					assert.equal context.main, fs.read temp 'first.html'
					assert.equal context.a, fs.read temp 'second.html'
					assert.equal context.b, third=fs.read temp 'third.html'
					assert.equal context.c, third.toUpperCase()


		test "es6ify", ()->
			@skip() if nodeVersion < 6
			Promise.resolve()
				.then ()->
					helpers.lib
						'main.js': """
							var {first, second} = import './a'
							class Custom {
								constructor(name) {
									this.name = name
								}
							}
							require('./b')
							exports.b = b
							exports.first = first
							exports.second = second
							exports.Custom = Custom
						"""
						'a.js': """
							var first = 'theFirst', second = 'theSecond';
							module.exports = {first, second}
						"""
						'b.js': """
							var b = function(a,b = 10){return a * b}
						"""
				.then ()-> processAndRun file:temp('main.js'), transform:'es6ify'
				.then ({compiled, result, context, writeToDisc})->
					assert.equal result.first, 'theFirst'
					assert.equal result.second, 'theSecond'
					assert.equal (new result.Custom 'dan').name, 'dan'
					assert.equal result.b(15), 150
					assert.equal result.b(15, 4), 60
					assert.notInclude compiled, 'class'









