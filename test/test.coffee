require 'clarify'
global.Promise = require('bluebird').config warnings:false, longStackTraces:false
mocha = require 'mocha'
fs = require 'fs-jetpack'
helpers = require './helpers'
{nodeVersion, emptyTemp, temp} = helpers
# require('../lib/defaults').sourceMap = false

if nodeVersion < 5.1
	Object.defineProperty Buffer,'from', value: (arg)-> new Buffer(arg)

mocha.Runner::fail = do ()->
	orig = mocha.Runner::fail
	(test, err)->
		err.stack = require('../lib/external/formatError').stack(err.stack)
		# err = require('../lib/external/formatError')(err)
		orig.call(@, test, err)
		setTimeout (()-> process.exit(1)), 200 unless process.env.CI







suite "SimplyImport", ()->
	suiteTeardown ()-> fs.removeAsync(temp())
	suiteSetup ()->
		Promise.resolve()
			.then emptyTemp
			.then ()-> Promise.all [
				fs.writeAsync temp('basicMain.js'), "var abc = require('./basic.js')\nvar def = require('./exportless')"
				fs.writeAsync temp('basic.js'), "module.exports = 'abc123'"
				fs.writeAsync temp('exportless.js'), "'def456'"
			]


	require './misc'
	require './options'
	require './paths'
	require './path-placeholders'
	require './inline-imports'
	require './es6-imports'
	require './commonjs-imports'
	require './exports'
	require './exclusion'
	require './module-loader'
	require './node-target'
	require './importInline'
	require './deduping'
	require './cyclic-imports'
	require './globals'
	require './transforms'
	require './extraction'
	require './conditionals'
	require './core-shims'
	require './umd-bundles'
	require './bin-files'
	require './common-modules'
	require './stubs'
	require './browserify'
	require './scan'
	require './sass'
	require './pug'
	require './http'
	require './source-maps'










