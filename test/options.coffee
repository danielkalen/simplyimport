fs = require 'fs-jetpack'
helpers = require './helpers'
{assert, expect, sample, debug, temp, tmp, processAndRun, SimplyImport, emptyTemp, badES6Support} = helpers


suite.skip "options", ()->
	suiteSetup ()-> Promise.all [
		createTransformer 'decodify'
		createTransformer 'envify'
		createTransformer 'colorify'
		createTransformer 'parsify'
		createTransformer 'cssify'
		createTransformer 'niceify'
	]

	test "should not be inherited from package.json if doesn't exist", ()->
		Promise.resolve()
			.then ()-> fs.dir tmp(), empty:true
			.then ()-> helpers.lib tmp(),
				'entry.js': "exports.abc = require('./child')"
				'child.js': "module.exports = 123"

			.then ()-> processAndRun file:tmp('entry.js')
			.then ({result})->
				assert.deepEqual result, {abc:123}
	
	test "for task should be inherited from package.json 'simplyimport' field", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'entry.js': "export var abc = 123"
				'package.json': JSON.stringify
					simplyimport: {usePaths:true, transform:['envify']}

			.then ()-> SimplyImport.task file:temp('entry.js'), transform:['colorify']
			.then (task)->
				assert.equal task.options.usePaths, true
				assert.deepEqual task.options.transform, ['colorify', 'envify']
				task.destroy()


	test "for file should be inherited from package.json 'simplyimport.specific' field", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'entry.js': "export var abc = 123"
				'package.json': JSON.stringify simplyimport:
					transform: ['envify']
					specific: 'entry.js': transform:['decodify']

			.then ()-> SimplyImport.task file:temp('entry.js'), transform:['colorify']
			.then (task)->
				assert.deepEqual task.options.transform, ['colorify', 'envify']
				assert.deepEqual task.entryFile.options.transform, ['colorify', 'envify', 'decodify']
				task.destroy()


	test "for external file should be inherited from own package and importer's package", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'entry.js': "export var abc = require('module-a')"
				'package.json': JSON.stringify simplyimport:
					transform: ['envify']
					specific:
						'entry.js': transform:['decodify']
						'module-a': transform:['decodify','parsify']
				
				'node_modules/module-a/index.js': "module.exports = 123"
				'node_modules/module-a/package.json': JSON.stringify simplyimport:
					transform: ['niceify']
					specific:
						'index.js': transform:['cssify']

			.then ()-> SimplyImport.task file:temp('entry.js'), transform:['colorify']
			.tap (task)-> Promise.resolve(task.entryFile).bind(task).then(task.processFile).then(task.scanStatements)
			.then (task)->
				assert.deepEqual task.options.transform, ['colorify', 'envify']
				assert.deepEqual task.entryFile.options.transform, ['colorify', 'envify', 'decodify']
				assert.deepEqual task.entryFile.statements[0].target.options.transform, ['niceify', 'cssify', 'decodify', 'parsify']
				task.destroy()



createTransformer = (name)->
	fs.writeAsync "node_modules/#{name}/index.js", 'module.exports = function(){return arguments[3]}'




