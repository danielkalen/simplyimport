fs = require 'fs-jetpack'
helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp} = helpers

suite "browserify compatibility", ()->
	Streamify = require 'streamify-string'
	Browserify = require 'browserify'
	Browserify::bundleAsync = Promise.promisify(Browserify::bundle)		

	test "packages that declare 'simplyimport/compat' transform will make the module compatibile", ()->
		compiled = null
		Promise.resolve()
			.then emptyTemp
			.then ()-> fs.symlinkAsync process.cwd(), temp('node_modules/simplyimport')
			.then ()->
				helpers.lib
					'node_modules/sm-module/main.js': """
						exports.a = import './a'
						exports.b = import './b $ nested.data'
						importInline './exportC'
						exports.d = (function(){
							return import './d'
						})()
						exports.other = import 'other-module'
					"""
					'node_modules/sm-module/a.js': """
						module.exports = 'abc-value';
					"""
					'node_modules/sm-module/b.json': """
						{"nested":{"data":"def-value"}}
					"""
					'node_modules/sm-module/c.yml': """
						nested:
                          data: 'gHi-value'
					"""
					'node_modules/sm-module/d.js': """
						export default jkl = 'jkl-value';
					"""
					'node_modules/sm-module/exportC.js': """
						exports.c = import 'c $ nested.data'
					"""
					'node_modules/sm-module/package.json': JSON.stringify
						main: 'index.js'
						browser: 'main.js'
						browserify: transform: [['simplyimport/compat', {'myOpts':true}]]
				
					'node_modules/other-module/package.json': JSON.stringify main:'index.js'
					'node_modules/other-module/index.js': "module.exports = 'abc123'"

			# .tap ()-> processAndRun(src:"module.exports = require('sm-module');", context:temp()).then(console.log).then ()-> process.exit()
			.then ()-> Browserify(Streamify("module.exports = require('sm-module');"), basedir:temp()).bundleAsync()
			# .tap (result)-> fs.writeAsync debug('browserify.js'), result
			.then (result)-> result.toString()
			.then (result)-> runCompiled('browserify.js', compiled=result, {})
			.then (result)->
				assert.typeOf result, 'function'
				assert.typeOf theModule=result(1), 'object'
				assert.equal theModule.a, 'abc-value'
				assert.equal theModule.b, 'def-value'
				assert.equal theModule.c, 'gHi-value'
				assert.equal theModule.d, 'jkl-value'
				assert.equal theModule.other, 'abc123'
				assert.include compiled, 'MODULE_NOT_FOUND'
	

	test "'simplyimport/compat' accepts a 'umd' option", ()->
		compiled = null
		Promise.resolve()
			.then emptyTemp
			.then ()-> fs.symlinkAsync process.cwd(), temp('node_modules/simplyimport')
			.then ()->
				helpers.lib
					'node_modules/sm-module/main.js': """
						exports.a = import './a'
						exports.b = import './b $ nested.data'
						exports.c = require('c $ nested.data')
						exports.d = (function(){
							return import './d'
						})()
						exports.other = import 'other-module'
					"""
					'node_modules/sm-module/a.js': """
						module.exports = 'abc-value';
					"""
					'node_modules/sm-module/b.json': """
						{"nested":{"data":"def-value"}}
					"""
					'node_modules/sm-module/c.yml': """
						nested:
                          data: 'gHi-value'
					"""
					'node_modules/sm-module/d.js': """
						export default jkl = 'jkl-value';
					"""
					'node_modules/sm-module/package.json': JSON.stringify
						main: 'index.js'
						browser: 'main.js'
						browserify: transform: [['simplyimport/compat', {'umd':'SMBundle'}]]
				
					'node_modules/other-module/package.json': JSON.stringify main:'index.js'
					'node_modules/other-module/index.js': "module.exports = 'abc123'"

			.then ()-> Browserify(Streamify("module.exports = require('sm-module');"), basedir:temp()).bundleAsync()
			.then (result)-> result.toString()
			.then (result)-> runCompiled('browserify.js', compiled=result, {})
			.then (result)->
				assert.typeOf result, 'function'
				assert.typeOf theModule=result(1), 'object'
				assert.equal theModule.a, 'abc-value'
				assert.equal theModule.b, 'def-value'
				assert.equal theModule.c, 'gHi-value'
				assert.equal theModule.d, 'jkl-value'
				assert.equal theModule.other, 'abc123'
				assert.include compiled, 'SMBundle'


	test "simplyimport bundles will skip 'simplyimport/compat'", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'package.json': JSON.stringify browserify:{transform:['simplyimport/compat','test/helpers/replacerTransform']}
					'main.js': """
						a = import 'module-a'
						b = import 'module-b'
						c = import './c'
						d = 'gHi'
					"""
					'c.js': """
						ghi = 'gHi-value'
					"""
				
					'node_modules/module-a/package.json': JSON.stringify browserify:{transform:[['simplyimport/compat', data:1], 'test/helpers/lowercaseTransform']}
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










