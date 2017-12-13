helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

suite "paths", ()->
	test "an import path can be extension-less", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './aaa'
						a2 = import './aaa.js'
						b = require('./bbb')
						c = import './ccc'
					"""
					'aaa.js': """
						module.exports = 'abc123'
					"""
					'bbb.nonjs': """
						module.exports = 'def456'
					"""
					'ccc.json': """
						{"a":1, "b":2}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'abc123'
				assert.equal context.a2, 'abc123'
				assert.equal context.b, 'def456'
				assert.deepEqual context.c, {a:1,b:2}


	test "if the provided import path matches a directory it will be searched for an index file", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a'
						b = require('./b')
						c = import './c'
					"""
					'a/index.js': """
						module.exports = 'abc123'
					"""
					'b/_index.nonjs': """
						module.exports = 'def456'
					"""
					'c/index.json': """
						{"a":1, "b":2}
					"""
					'c/distraction.json': """
						{"a":2, "b":4}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'abc123'
				assert.equal context.b, 'def456'
				assert.deepEqual context.c, {a:1,b:2}


	test "extension-less import paths that match a directory and a file will have the file take precedence", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './abc'
						b = require('./def')
						c = importInline './ghi'
					"""
					'abc.js': """
						module.exports = 'ABC123'
					"""
					'abc/index.js': """
						module.exports = 'abc123'
					"""
					'def.nonjs': """
						module.exports = 'DEF456'
					"""
					'def/index.js': """
						module.exports = 'def456'
					"""
					'ghi.other.json': """
						{"a":1, "b":2}
					"""
					'ghi/__index.json': """
						{"a":2, "b":4}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'ABC123'
				assert.equal context.b, 'DEF456'
				assert.deepEqual context.c, {a:2,b:4}


	test "extension-less import paths that match a directory and a file will have the directory take precedence if the path ends with a slash", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'abc.js': "module.exports = 'abc.js'"
					'abc/index.js': "module.exports = 'abc/index.js'"

			.then ()-> processAndRun file:temp('main.js'), src:"module.exports = import './abc'"
			.then ({result})-> assert.equal result, 'abc.js'

			.then ()-> processAndRun file:temp('main.js'), src:"module.exports = import './abc/'"
			.then ({result})-> assert.equal result, 'abc/index.js'


	test "extension-less import paths that match a js file and a non-js file will have the js take precedence", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './abc'
						b = require('./abc')
						c = importInline 'abc'
					"""
					'abc.js': """
						module.exports = 'ABC123'
					"""
					'abc.json': """
						{"a":1, "b":2}
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.a, 'ABC123'
				assert.equal context.b, 'ABC123'
				assert.equal context.c, 'ABC123'


	test "import paths not starting with '.' or '/' will be attempted to load from node_modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
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


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'def456'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'


	test "if a node_modules-compatible path isn't matched in node_modules it will be treated as a local path", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						abc = import 'abc'
						ghi = importInline 'ghi/file'
						def = require("def")
					"""
					'abc.js': """
						module.exports = 'abc123'
					"""
					'node_modules/def/nested/index.js': """
						module.exports = 'DEF456'
					"""
					'def/index.js': """
						module.exports = 'def456'
					"""
					'ghi/file.js': """
						theGhi = 'ghi789'
					"""


			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc123'
				assert.equal context.def, 'def456'
				assert.equal context.ghi, 'ghi789'
				assert.equal context.theGhi, 'ghi789'








