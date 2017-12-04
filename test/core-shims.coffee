Path = require 'path'
helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "core module shims", ()->
	test "assert", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('assert')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'function'
				assert.doesNotThrow ()-> result.ok(true)
				assert.throws ()-> result.ok(false)
				assert.doesNotThrow ()-> result.deepEqual([10,20,30], [10,20,30])
				assert.throws ()-> result.deepEqual([10,20,30,40],[10,20,30])


	test "buffer", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('buffer')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				result = result.Buffer
				assert.typeOf result, 'function'
				assert.doesNotThrow ()-> result.from('test')
				assert.equal 0, result.compare result.from('test'), result.from('test')


	test "console", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('console')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.log, 'function'
				assert.doesNotThrow ()-> result.log 'test'
				assert.doesNotThrow ()-> result.warn 'test'
				assert.doesNotThrow ()-> result.trace 'test'


	test "constants", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('constants')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				keys = Object.keys result
				assert.include keys, 'NPN_ENABLED'
				assert.include keys, 'F_OK'
				assert.include keys, 'DH_NOT_SUITABLE_GENERATOR'


	test "domain", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('domain')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.create, 'function'
				assert.doesNotThrow ()-> result.create()


	test "events", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('events')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'function'
				assert.doesNotThrow ()-> new result()
				assert.deepEqual (new result())._events, (new (require 'events'))._events


	test "http", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('http')"
			.then ()-> processAndRun file:temp('main.js'), usePaths:true, null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
			.then ({result, writeToDisc})->
				assert.typeOf result, 'object'
				assert.typeOf result.get, 'function'
				result.get('http://google.com').abort()


	test "https", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('https')"
			.then ()-> processAndRun file:temp('main.js'), usePaths:true, null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
			.then ({result, writeToDisc})->
				assert.typeOf result, 'object'
				assert.typeOf result.get, 'function'
				result.get('https://google.com').abort()


	test "util", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('util')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.isArray, 'function'
				assert.equal result.isArray([]), require('util').isArray([])
				assert.equal result.isArray({}), require('util').isArray({})


	test "os", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('os')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.uptime, 'function'
				assert.equal result.uptime(), 0


	test "path", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('path')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.resolve, 'function'
				assert.equal result.resolve('/abc'), Path.resolve('/abc')


	test "punycode", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('punycode')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.encode, 'function'
				assert.equal result.encode('例.com'), result.encode result.decode result.encode('例.com')


	test "querystring", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('querystring')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.encode, 'function'
				assert.equal result.encode('abc.com/simply-&-import'), require('querystring').encode('abc.com/simply-&-import')


	test "string_decoder", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('string_decoder')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.StringDecoder, 'function'
				assert.doesNotThrow ()-> new result.StringDecoder('utf8')


	test "stream", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('stream')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'function'
				assert.typeOf result.Readable, 'function'
				assert.doesNotThrow ()-> new result.Writable


	test "timers", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('timers')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.setImmediate, 'function'


	test "tty", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('tty')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.ReadStream, 'function'


	test "url", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('url')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.parse, 'function'
				require('assert').deepEqual result.parse('https://google.com'), require('url').parse('https://google.com')


	test "vm", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('vm')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.runInNewContext, 'function'
				# assert.deepEqual result.parse('https://google.com'), require('url').parse('https://google.com')


	test "zlib", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('zlib')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.createGzip, 'function'
				assert.doesNotThrow ()-> result.createGzip()


	test "crypto", ()->
		@timeout 5e4
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('crypto')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.createHmac, 'function'
				assert.equal result.createHmac('sha256','abc').update('s').digest('hex'), require('crypto').createHmac('sha256','abc').update('s').digest('hex')


	test "unshimmable core modules", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				"main.js": """
					exports.cluster = require('cluster')
					exports.dgram = require('dgram')
					exports.dns = require('dns')
					exports.fs = require('fs')
					exports.module = require('module')
					exports.net = require('net')
					exports.readline = require('readline')
					exports.repl = require('repl')
				"""
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.deepEqual result.cluster, {}
				assert.deepEqual result.dgram, {}
				assert.deepEqual result.dns, {}
				assert.deepEqual result.fs, {}
				assert.deepEqual result.module, {}
				assert.deepEqual result.net, {}
				assert.deepEqual result.readline, {}
				assert.deepEqual result.repl, {}










