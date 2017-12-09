fs = require 'fs-jetpack'
helpers = require './helpers'
{assert, expect, sample, temp, processAndRun, emptyTemp, SimplyImport} = helpers

suite "UMD bundles", ()->
	suiteSetup emptyTemp
	
	test "will not have their require statements scanned", ()->
		scanResults = raw:null, umd:null
		runtimeResults = raw:null, umd:null
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = import './a'
						exports.b = require('./b')
						exports.c = import './c'
					"""
					'a.js': "module.exports = 'abc'"
					'b.js': "module.exports = 'def'"
					'c.js': "module.exports = require('./c-hidden')"
					'c-hidden.js': "module.exports = 'jhi'"

			.then ()-> processAndRun file:temp('main.js'), umd:'main', usePaths:true
			.tap ({result})-> runtimeResults.raw = result
			.tap ({compiled})-> fs.writeAsync temp('umd.js'), compiled
			
			.then ()-> processAndRun file:temp('umd.js')
			.tap ({result})-> runtimeResults.umd = result
			
			.then ()-> SimplyImport.scan file:temp('main.js'), depth:Infinity
			.then (result)-> scanResults.raw = result
			
			.then ()-> SimplyImport.scan file:temp('umd.js'), depth:Infinity
			.then (result)-> scanResults.umd = result

			.then ()->
				assert.equal runtimeResults.raw.a, runtimeResults.umd.a
				assert.equal runtimeResults.raw.b, runtimeResults.umd.b
				assert.equal runtimeResults.raw.c, runtimeResults.umd.c
				assert.deepEqual scanResults.raw, [
					temp('a.js')
					temp('b.js')
					temp('c.js')
					temp('c-hidden.js')
				]
				assert.deepEqual scanResults.umd, []


	test "will have their require statements scanned if the require variable is never defined", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = require('module-a')
						exports.b = require('module-b')
						exports.c = require('module-c')
					"""
					'node_modules/prefix-a/index.js': """
						module.exports = 'module-';
					"""
					'node_modules/prefix-b/index.js': """
						module.exports = 'MODULE-';
					"""
					'node_modules/prefix-c/index.js': """
						module.exports = 'MoDuLe-';
					"""
					'node_modules/module-a/index.js': """
						module.exports = require('prefix-a')+'a';
					"""
					'node_modules/module-b/index.js': """
						if (typeof module !== 'undefined' && typeof exports !== 'undefined') {
							var thePrefix = require('prefix-b')
						}
						module.exports = thePrefix+'b';
					"""
					'node_modules/module-c/index.js': """
						(function(require){
							if (typeof module !== 'undefined' && typeof exports !== 'undefined') {
								var thePrefix = require('prefix-c')
							}
							module.exports = thePrefix+'c';
						})(function(){return 'noprefix-'})
					"""
			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({result, compiled})->
				assert.equal result.a, 'module-a'
				assert.equal result.b, 'MODULE-b'
				assert.equal result.c, 'noprefix-c'
				assert.include compiled, "'module-'"
				assert.include compiled, "'MODULE-'"
				assert.notInclude compiled, "'MoDuLe-'"


	test "can be imported", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						exports.a = import 'moment/moment.js'
						exports.b = import 'moment/src/moment.js'
					"""

			.then ()-> processAndRun file:temp('main.js'),usePaths:true
			.then ({result, writeToDisc})->
				writeToDisc()
				now = Date.now()
				assert.notEqual result.a, result.b
				assert.typeOf result.a, 'function'
				assert.typeOf result.b, 'function'
				assert.equal result.a(now).subtract(1, 'hour').valueOf(), result.b(now).subtract(1, 'hour').valueOf()











