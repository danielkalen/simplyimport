helpers = require './helpers'
{assert, expect, temp, processAndRun, emptyTemp, SimplyImport} = helpers

suite "extraction", ()->
	suiteSetup emptyTemp
	
	test "specific fields can be imported from JSON files by specifying a property after the file path separated by '$'", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json$dataPointA'
						b = require('b.json$dataPointB')
						c = require('./c$dataPointC')
					"""
					'a.json': """
						{
							"dataPointA": {"a":1, "A":10, "AA":100},
							"dataPointB": {"b":2, "B":20, "BB":200},
							"dataPointC": {"c":3, "C":30, "CC":300}
						}
					"""
					'b.json': """
						{
							"dataPointA": {"a":1, "A":10, "AA":100},
							"dataPointB": {"b":2, "B":20, "BB":200},
							"dataPointC": {"c":3, "C":30, "CC":300}
						}
					"""
					'c.json': """
						{
							"dataPointA": {"a":1, "A":10, "AA":100},
							"dataPointB": {"b":2, "B":20, "BB":200},
							"dataPointC": {"c":3, "C":30, "CC":300}
						}
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.notInclude compiled, 'require ='
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.typeOf context.c, 'object'
				assert.deepEqual context.a, {"a":1, "A":10, "AA":100}
				assert.deepEqual context.b, {"b":2, "B":20, "BB":200}
				assert.deepEqual context.c, {"c":3, "C":30, "CC":300}


	test "extraction properties can be deep", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json$dataPointA.simply import.abc[1]'
						b = require('b.json$dataPointB[13-seep].def[0]')
					"""
					'a.json': """
						{
							"dataPointA": {"a":1, "A":10, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
							"dataPointB": {"b":2, "B":20, "BB":200}
						}
					"""
					'b.json': """
						{
							"dataPointA": {"a":1, "A":10, "AA":100},
							"dataPointB": {"b":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "BB":100}
						}
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.notInclude compiled, 'require ='
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.deepEqual context.a, {"ABC":456}
				assert.deepEqual context.b, {"DEF":123}


	test "the '$' separator can have whitespace surrounding it", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json   $ dataPointA.simply import.abc[1]'
					"""
					'a.json': """
						{
							"dataPointA": {"a":1, "A":10, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
							"dataPointB": {"b":2, "B":20, "BB":200}
						}
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.notInclude compiled, 'require ='
				assert.notInclude compiled, 'dataPointB'
				assert.typeOf context.a, 'object'
				assert.deepEqual context.a, {"ABC":456}


	test "duplicate imports when all are extraction imports", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json $ dataPointA.simply import.abc[1]'
						b = require('a.json $ dataPointA[13-seep].def[0]')
					"""
					'a.json': """
						{
							"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
							"dataPointB": {"b":2, "B":20, "BB":200}
						}
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.include compiled, 'require ='
				assert.notInclude compiled, 'dataPointB'
				assert.notInclude compiled, 'abc123'
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.deepEqual context.a, {"ABC":456}
				assert.deepEqual context.b, {"DEF":123}


	test "duplicate imports when some are extraction imports", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json $ dataPointA.simply import.abc[1]'
						b = require('a.json $ dataPointA["13-seep"].def[0]')
						c = require('a.json')
					"""
					'a.json': """
						{
							"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
							"dataPointB": {"b":2, "B":20, "BB":200}
						}
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.include compiled, 'require ='
				assert.include compiled, 'dataPointB'
				assert.include compiled, 'abc123'
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.typeOf context.c, 'object'
				assert.deepEqual context.a, {"ABC":456}
				assert.deepEqual context.b, {"DEF":123}
				assert.equal context.c['dataPointA.simply import.abc[1]'], context.a
				assert.equal context.c['dataPointA[13-seep].def[0]'], context.b


	test "invalid syntax data files will cause ParseError to be thrown", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import './a.json $ dataPointA'
					"""
					'a.json': """
						{
							"dataPointA": {"abc123":1, "13-seep":{"def":[{"DEF":123},{"DEF":456}]}, "simply import":{"abc":[{"ABC":123},{"ABC":456}]}},
							"dataPointB": {"b:2, "B":20, BB:200}
						}
					"""
			.then ()-> SimplyImport file:temp('main.js')
			.catch (err)-> assert.include(err.message, 'Unexpected'); 'failed as expected'
			.then (result)-> assert.equal result, 'failed as expected'


	test "data can be extracted from cson files", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import './insertA'
						b = require('a.cson $ dataPointA[13-seep].def[0]')
						c = require('b.cson$dataPointC.inner')
					"""
					'insertA.js': """
						a = import './a.cson $ dataPointA.simply import.abc[1]'
					"""
					'a.cson': """
						dataPointA:
							abc123: 1
							'13-seep':
								def:[
									{"DEF":123}
									{"DEF":456}
								]
							"simply import":{"abc":[{"ABC":123},{"ABC":456}]}
						
						"dataPointB": {"b":2, "B":20, "BB":200}
					"""
					'b.cson': """
						dataPointC:
							inner: 'theString'
						dataPointD:
							inner: 30
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				assert.include compiled, 'require ='
				assert.notInclude compiled, 'dataPointB'
				assert.notInclude compiled, 'abc123'
				assert.notInclude compiled, 'dataPointD'
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.typeOf context.c, 'string'
				assert.deepEqual context.a, {"ABC":456}
				assert.deepEqual context.b, {"DEF":123}
				assert.deepEqual context.c, 'theString'


	test "data can be extracted from yml files", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						importInline './insertA'
						b = require('a.yml $ dataPointA[13-seep].def[0]')
						c = require('b.yml$dataPointC.inner')
					"""
					'insertA.js': """
						a = import './a.yml $ dataPointA.simply import.abc[1]'
					"""
					'a.yml': """
						dataPointA:
						  abc123: 1
						  13-seep:
						    def:
						      - DEF: 123
						      - DEF: 456
						  simply import:
						    abc:
						      - ABC: 123
						      - ABC: 456

						dataPointB:
						  b:2
						  B:20
						  BB:200
					"""
					'b.yml': """
						dataPointC:
						  inner: 20
						dataPointD:
						  inner: 30
					"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, context, writeToDisc})->
				writeToDisc()
				assert.include compiled, 'require ='
				assert.notInclude compiled, 'dataPointB'
				assert.notInclude compiled, 'abc123'
				assert.notInclude compiled, 'dataPointD'
				assert.typeOf context.a, 'object'
				assert.typeOf context.b, 'object'
				assert.typeOf context.c, 'number'
				assert.deepEqual context.a, {"ABC":456}
				assert.deepEqual context.b, {"DEF":123}
				assert.deepEqual context.c, 20


	test "entry files of data types will support importInline statements", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.json': """
					{
						"main": "index.js",
						"version": "1.0.0",
						"a": importInline "./a-file",
						"size": "12",
						"b": importInline "./b-file"
					}
					"""
					'a-file.json': """
					{
						"main": "a.js",
						"version": "2.0.0"
					}
					"""
					'b-file.json': """
					{
						"main": "b.js",
						"version": "3.0.0"
					}
					"""

			.then ()-> SimplyImport file:temp('main.json')
			.then (compiled)->
				parsed = null
				assert.notInclude compiled, 'require'
				assert.doesNotThrow ()-> parsed = JSON.parse(compiled)
				assert.equal parsed.main, 'index.js'
				assert.equal parsed.version, '1.0.0'
				assert.equal parsed.size, '12'
				assert.equal parsed.a.main, 'a.js'
				assert.equal parsed.b.main, 'b.js'
				assert.equal parsed.a.version, '2.0.0'
				assert.equal parsed.b.version, '3.0.0'










