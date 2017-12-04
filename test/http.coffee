Path = require 'path'
fs = require 'fs-jetpack'
helpers = require './helpers'
{assert, expect, temp, processAndRun, SimplyImport} = helpers

suite "http imports", ()->
	suiteTeardown ()-> require('nock').restore()
	suiteSetup ()->
		@slow(1e4)
		TarGZ = require('tar.gz')()
		mock = (host, path, reply...)->
			require('nock')(host).persist()
				.get(path).reply(reply...)
				.head(path).reply(reply...)
		
		Promise.resolve()
			.then ()-> fs.dir require('../lib/helpers/temp')(), empty:true
			.then ()->
				mock('https://example.com', '/a', 200, 'module.exports = "module-a"')
				mock('https://example.com', '/b', 200, 'module.exports = "module-b"')
				mock('https://example.com', '/c', 200, 'module.exports = {dir:__dirname, file:__filename}', etag:'abc123')
				mock('https://example.com', '/d.js', 200, 'module.exports = {dir:__dirname, file:__filename}')
				mock('https://example.com', '/e.json', 200, JSON.stringify main:'index.js', version:'1.2.3-alpha')
				mock('https://example.com', '/f', 301, '', 'location':'https://example.com/f2')
				mock('https://example.com', '/f2', 200, 'module.exports = "module-f"')
				mock('https://example.com', '/g', 403, 'unauthorized')
				mock('https://example.com', '/h', 500)
			.then ()->
				helpers.lib
					'someModuleA/entrypoint.js': """
						exports.a = import './childA'
						exports.b = import './childB'
						exports.dir = __dirname
						exports.file = __filename
					"""
					'someModuleA/childA.js': "module.exports = 'I am childA'"
					'someModuleA/childB.js': "module.exports = 'I am childB'"
					'someModuleA/childB.coffee': "module.exports = 'I am childB-coffee'"
					'someModuleA/package.json': JSON.stringify
						main: 'entrypoint.js'
						browser: './childB.js':'./childB.coffee'

			.then ()-> TarGZ.compress temp('someModuleA'), temp('someModuleA.tgz')
			.then ()-> fs.copyAsync temp('someModuleA.tgz'), temp('someModuleB.tgz')
			.then ()->
				mock('https://example.com', '/moduleA.tgz', 200, fs.read(temp('someModuleA.tgz'), 'buffer'), etag:'theFirstModule')
				mock('https://example.com', '/moduleB.tar.gz', 200, fs.read(temp('someModuleB.tgz'), 'buffer'), etag:'theSecondModule')


	test "js files can be downloaded and used as modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = import 'https://example.com/a'
						exports.b = require('https://example.com/b')
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.deepEqual result, a:'module-a', b:'module-b'


	test "downloads will be cached to temp folder when etag header exists", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.main = import 'https://example.com/c'
						exports.child = import './child'
					"""
					'child.js': """
						module.exports = import 'https://example.com/c'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.deepEqual result.main, result.child
				assert.equal Path.resolve(result.main.dir), require('../lib/helpers/temp')()
				assert.equal Path.resolve(result.main.file), require('../lib/helpers/temp')()+'/abc123.js'


	test "downloads will be cached to temp folder when etag header does not exists", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						module.exports = import 'https://example.com/d.js'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.equal Path.resolve(result.dir), require('../lib/helpers/temp')()
				assert.include Path.resolve(result.file), require('../lib/helpers/temp')()


	test "non-js files can be downloaded", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						module.exports = import 'https://example.com/e.json $ version'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'string'
				assert.equal result, '1.2.3-alpha'


	test "tarballs can be donwloaded and will be treated as packages", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = import 'https://example.com/moduleA.tgz'
						exports.b = import 'https://example.com/moduleB.tar.gz'
					"""

			.then ()-> processAndRun file:temp('main.js'), dedupe:false
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.a, 'object'
				assert.typeOf result.b, 'object'
				assert.equal result.a.a, 'I am childA'
				assert.equal result.b.a, 'I am childA'
				assert.equal result.a.b, 'I am childB-coffee'
				assert.equal result.b.b, 'I am childB-coffee'
				assert.equal Path.resolve(result.a.dir), require('../lib/helpers/temp')()+'/theFirstModule'
				assert.equal Path.resolve(result.a.file), require('../lib/helpers/temp')()+'/theFirstModule/entrypoint.js'
				assert.equal Path.resolve(result.b.dir), require('../lib/helpers/temp')()+'/theSecondModule'
				assert.equal Path.resolve(result.b.file), require('../lib/helpers/temp')()+'/theSecondModule/entrypoint.js'


	test "redirects will be followed", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						module.exports = import 'https://example.com/f'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.equal result, 'module-f'


	test "error will be thrown on response statuses >= 400", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'403.js': """
						module.exports = import 'https://example.com/g'
					"""
					'500.js': """
						module.exports = import 'https://example.com/h'
					"""

			.then ()->
				Promise.resolve()
					.then ()-> SimplyImport file:temp('403.js')
					.then ()-> assert false
					.catch (err)-> assert.include err.message, 'failed to download https://example.com/g (403)'
					.then ()-> SimplyImport file:temp('500.js')
					.then ()-> assert false
					.catch (err)-> assert.include err.message, 'failed to download https://example.com/h (500)'









