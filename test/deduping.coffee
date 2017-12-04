helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "deduping", ()->
	# suiteTeardown ()-> fs.dirAsync temp(), empty:true 
	
	test "will be enabled by default", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						aaa = import 'module-a';
						bbb = import 'module-b';
						ccc = import 'module-c';
						ddd = import 'module-d';
					"""
					"node_modules/module-a/index.js": """
						module.exports = require('module-c')+'-aaa';
					"""
					"node_modules/module-b/index.js": """
						module.exports = require('module-d')+'-bbb';
					"""
					"node_modules/module-c/index.js": """
						module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
					"""
					"node_modules/module-d/index.js": """
						module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.ccc, context.ddd, 'ccc === ddd'
				assert.equal context.aaa, context.ddd+'-aaa'
				assert.equal context.bbb, context.ddd+'-bbb'


	test "will be disabled when options.dedupe is false", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						aaa = import 'module-a';
						bbb = import 'module-b';
						ccc = import 'module-c';
						ddd = import 'module-d';
					"""
					"node_modules/module-a/index.js": """
						module.exports = require('module-c')+'-aaa';
					"""
					"node_modules/module-b/index.js": """
						module.exports = require('module-d')+'-bbb';
					"""
					"node_modules/module-c/index.js": """
						module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
					"""
					"node_modules/module-d/index.js": """
						module.exports = Math.floor((1+Math.random()) * 100000).toString(16);
					"""

			.then ()-> processAndRun file:temp('main.js'), dedupe:false
			.then ({context})->
				assert.notEqual context.ccc, context.ddd, 'ccc !== ddd'
				assert.equal context.aaa, context.ccc+'-aaa'
				assert.equal context.bbb, context.ddd+'-bbb'





