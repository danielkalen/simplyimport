Path = require 'path'
helpers = require './helpers'
{assert, expect, temp, emptyTemp, SimplyImport} = helpers

suite "scan imports", ()->
	suiteSetup ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = import './a'
						exports.b = require('b')
						import './c'
						import d from './d'
						import * as e from './e'
						exports.f = import './f$version'
						exports.g = import './g $ nested.version'
						export * from 'nested'
					"""
					'main2.js': ['main.js', (content)-> content.replace "import './c'", "importInline './c'"]
					'main.cyclic.js': ['main.js', (content)-> content.replace "from './d'", "from './d2'"]
					'main.errors.js': ['main.js', (content)-> content.replace "from './d'", "from './d3'"]
					"main.conditionals.js": """
						import './a'

						// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
						require('b')
						// simplyimport:end

						// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
						import './c'
						// simplyimport:end

						import d from './d'

						// simplyimport:if VAR_A == 'gibberish'
						import * as e from './e'
						// simplyimport:end
					"""
					'main.emptyStubs.js': """
						exports.a = import './a'
						exports.b = import './b'
						exports.c = import './ccc-undefined'
						exports.d = import './d'
					"""
					'a.js': "import 'a2'"
					'a2.js': "module.exports = 'file a2.js'"
					'b.js': "module.exports = 'file b.js'"
					'c.js': "import 'c2'"
					'c2/index.coffee': "module.exports = do -> import './nested'"
					'c2/nested.coffee': "'file c2.coffee'"
					'd/index.js': "export default value = 'file d.js'"
					'd2/index.js': "export default value = require('./cyclic.js')"
					'd2/cyclic.js': "module.exports = require('../main.cyclic.js')"
					'd3/index.js': "export default value = require('./errors.js') + require('./noerrors.js')"
					'd3/errors.js': "module.exports = ()-> 1..2.2.3."
					'e.js': "var value='file e.js';\nexport {value}"
					'f.json': """
						{"version":"1.0.5"}
					"""
					'g.yaml': """
						nested:
						  version: 2.8.5
					"""
					'nested/_index.js': """
						exports.nestedA = require('./a.js ')
						exports.nestedB = import './b.js'
					"""
					'nested/a.js': "module.exports = 'file nested/a.js'"
					'nested/b.js': "module.exports = import './b2'"
					'nested/b2.js': "module.exports = 'file nested/b2.js'"


	test "basic flat scan (default)", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.js')
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.notInclude result,	temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'c.js'
				assert.notInclude result,	temp 'c2/index.coffee'
				assert.notInclude result,	temp 'c2/nested.coffee'
				assert.include result,		temp 'd/index.js'
				assert.include result,		temp 'e.js'
				assert.include result,		temp 'f.json'
				assert.include result,		temp 'g.yaml'
				assert.include result,		temp 'nested/_index.js'
				assert.notInclude result,	temp 'nested/a.js'
				assert.notInclude result,	temp 'nested/b.js'
				assert.notInclude result,	temp 'nested/b2.js'


	test "scan depth can be controlled with options.depth", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.js'), depth:1
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.include result,		temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'c.js'
				assert.include result,		temp 'c2/index.coffee'
				assert.notInclude result,	temp 'c2/nested.coffee'
				assert.include result,		temp 'd/index.js'
				assert.include result,		temp 'e.js'
				assert.include result,		temp 'f.json'
				assert.include result,		temp 'g.yaml'
				assert.include result,		temp 'nested/_index.js'
				assert.include result,		temp 'nested/a.js'
				assert.include result,		temp 'nested/b.js'
				assert.notInclude result,	temp 'nested/b2.js'


	test "importInline statements will ignore depth", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main2.js')
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.notInclude result,	temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'c.js'
				assert.include result,	temp 'c2/index.coffee'
				assert.notInclude result,	temp 'c2/nested.coffee'
				assert.include result,		temp 'd/index.js'
				assert.include result,		temp 'e.js'
				assert.include result,		temp 'f.json'
				assert.include result,		temp 'g.yaml'
				assert.include result,		temp 'nested/_index.js'
				assert.notInclude result,	temp 'nested/a.js'
				assert.notInclude result,	temp 'nested/b.js'
				assert.notInclude result,	temp 'nested/b2.js'


	test "paths will be relative when options.relativePaths is set", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.js'), depth:1, relativePaths:true
			.then (result)->
				tempRel = ()-> Path.relative process.cwd(), temp(arguments...)
				
				assert Array.isArray(result)
				assert.include result,		tempRel 'a.js'
				assert.include result,		tempRel 'a2.js'
				assert.include result,		tempRel 'b.js'
				assert.include result,		tempRel 'c.js'
				assert.include result,		tempRel 'c2/index.coffee'
				assert.notInclude result,	tempRel 'c2/nested.coffee'
				assert.include result,		tempRel 'd/index.js'
				assert.include result,		tempRel 'e.js'
				assert.include result,		tempRel 'f.json'
				assert.include result,		tempRel 'g.yaml'
				assert.include result,		tempRel 'nested/_index.js'
				assert.include result,		tempRel 'nested/a.js'
				assert.include result,		tempRel 'nested/b.js'
				assert.notInclude result,	tempRel 'nested/b2.js'


	test "syntax errors and missing files will be ignored", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.errors.js'), depth:Infinity
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.include result,		temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'c.js'
				assert.include result,		temp 'c2/index.coffee'
				assert.include result,		temp 'c2/nested.coffee'
				assert.include result,		temp 'd3/index.js'
				assert.include result,		temp 'd3/errors.js'
				assert.include result,		temp 'e.js'
				assert.include result,		temp 'f.json'
				assert.include result,		temp 'g.yaml'
				assert.include result,		temp 'nested/_index.js'
				assert.include result,		temp 'nested/a.js'
				assert.include result,		temp 'nested/b.js'
				assert.include result,		temp 'nested/b2.js'


	test "nested scan (options.flat = false)", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.js'), depth:Infinity, flat:false
			.then (result)->
				assert Array.isArray(result)
				assert.typeOf result[0], 'object'
				assert.deepEqual result, [
					file: temp('a.js')
					imports: [
						file: temp('a2.js')
						imports: []
					]
				,
					file: temp('b.js')
					imports: []
				,
					file: temp('c.js')
					imports: [
						file: temp('c2/index.coffee')
						imports: [
							file: temp('c2/nested.coffee')
							imports: []
						]
					]
				,
					file: temp('d/index.js')
					imports: []
				,
					file: temp('e.js')
					imports: []
				,
					file: temp('f.json')
					imports: []
				,
					file: temp('g.yaml')
					imports: []
				,
					file: temp('nested/_index.js')
					imports: [
						file: temp('nested/a.js')
						imports: []
					,
						file: temp('nested/b.js')
						imports: [
							file: temp('nested/b2.js')
							imports: []
						]
					]
				]


	test "nested scan with options.depth:0", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.js'), flat:false
			.then (result)->
				assert Array.isArray(result)
				assert.typeOf result[0], 'object'
				assert.deepEqual result, [
					file: temp('a.js')
					imports: []
				,
					file: temp('b.js')
					imports: []
				,
					file: temp('c.js')
					imports: []
				,
					file: temp('d/index.js')
					imports: []
				,
					file: temp('e.js')
					imports: []
				,
					file: temp('f.json')
					imports: []
				,
					file: temp('g.yaml')
					imports: []
				,
					file: temp('nested/_index.js')
					imports: []
				]


	test "cyclic refs will be excluded", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.cyclic.js'), depth:Infinity, flat:false
			.then (result)->
				# console.dir result, colors:true, depth:Infinity
				assert Array.isArray(result)
				assert.typeOf result[0], 'object'
				assert.deepEqual result, [
					file: temp('a.js')
					imports: [
						file: temp('a2.js')
						imports: []
					]
				,
					file: temp('b.js')
					imports: []
				,
					file: temp('c.js')
					imports: [
						file: temp('c2/index.coffee')
						imports: [
							file: temp('c2/nested.coffee')
							imports: []
						]
					]
				,
					file: temp('d2/index.js')
					imports: [
						file: temp('d2/cyclic.js')
						imports: []
					]
				,
					file: temp('e.js')
					imports: []
				,
					file: temp('f.json')
					imports: []
				,
					file: temp('g.yaml')
					imports: []
				,
					file: temp('nested/_index.js')
					imports: [
						file: temp('nested/a.js')
						imports: []
					,
						file: temp('nested/b.js')
						imports: [
							file: temp('nested/b2.js')
							imports: []
						]
					]
				]


	test "cyclic refs will be included when options.cyclic is set", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.cyclic.js'), depth:Infinity, flat:false, cyclic:true
			.then (result)->
				# console.dir result, colors:true, depth:Infinity
				assert Array.isArray(result)
				assert.typeOf result[0], 'object'
				assert.deepEqual result, [
					file: temp('a.js')
					imports: [
						file: temp('a2.js')
						imports: []
					]
				,
					file: temp('b.js')
					imports: []
				,
					file: temp('c.js')
					imports: [
						file: temp('c2/index.coffee')
						imports: [
							file: temp('c2/nested.coffee')
							imports: []
						]
					]
				,
					file: temp('d2/index.js')
					imports: [
						file: temp('d2/cyclic.js')
						imports: [
							file: temp('main.cyclic.js')
							imports: result
						]
					]
				,
					file: temp('e.js')
					imports: []
				,
					file: temp('f.json')
					imports: []
				,
					file: temp('g.yaml')
					imports: []
				,
					file: temp('nested/_index.js')
					imports: [
						file: temp('nested/a.js')
						imports: []
					,
						file: temp('nested/b.js')
						imports: [
							file: temp('nested/b2.js')
							imports: []
						]
					]
				]


	test "imports inside conditionals will be included", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.conditionals.js'), depth:Infinity
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.include result,		temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'c.js'
				assert.include result,		temp 'c2/index.coffee'
				assert.include result,		temp 'c2/nested.coffee'
				assert.include result,		temp 'd/index.js'
				assert.include result,		temp 'e.js'


	test "imports inside conditionals will not be included when options.matchAllConditions is false", ()->
		Promise.resolve()
			.then ()->
				process.env.VAR_A = 'abc'
				process.env.VAR_B = 'def'
			.then ()-> SimplyImport.scan file:temp('main.conditionals.js'), depth:Infinity, matchAllConditions:false
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.include result,		temp 'a2.js'
				assert.include result,		temp 'b.js'
				assert.notInclude result,	temp 'c.js'
				assert.notInclude result,	temp 'c2/index.coffee'
				assert.notInclude result,	temp 'c2/nested.coffee'
				assert.include result,		temp 'd/index.js'
				assert.notInclude result,	temp 'e.js'


	test "empty stubs will be removed in flat scans", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.emptyStubs.js')
			.then (result)->
				assert Array.isArray(result)
				assert.include result,		temp 'a.js'
				assert.include result,		temp 'b.js'
				assert.include result,		temp 'd/index.js'
				assert.notInclude result,	temp 'c.js'
				assert.notInclude result,	temp 'ccc-undefined.js'
				assert.notInclude result,	temp 'c2/index.coffee'
				assert.notInclude result,	require('../lib/constants').EMPTY_STUB


	test "empty stubs will be removed in nested scans", ()->
		Promise.resolve()
			.then ()-> SimplyImport.scan file:temp('main.emptyStubs.js'), flat:false, depth:Infinity
			.then (result)->
				assert Array.isArray(result)
				assert.deepEqual result, [
					file: temp('a.js')
					imports: [
						file: temp('a2.js')
						imports: []
					]
				,
					file: temp('b.js')
					imports: []
				,
					file: temp('d/index.js')
					imports: []
				]


	test "no duplicates", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'duplicates.js': """
						import './aaa'
						import './bbb'
						import './ccc'
					"""
					'aaa.js': "module.exports = import './bbb'"
					'bbb.js': "module.exports = import './ccc'"
					'ccc.js': "module.exports = import './aaa'"
			.then ()-> SimplyImport.scan file:temp('duplicates.js')
			.then (result)->
				assert Array.isArray(result)
				assert.equal result.length, 3
				assert.deepEqual result, [
					temp('aaa.js')
					temp('bbb.js')
					temp('ccc.js')
				]










