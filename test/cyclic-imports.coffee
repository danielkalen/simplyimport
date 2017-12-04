helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers


suite "cyclic imports", ()->
	test "are supported between 2-chain imported modules", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					"main.js": """
						aaa = import './a.js';
						bbb = import './b.js';
					"""
					"a.js": """
						var abc;
						exports.result = abc = 100;
						exports.combined = function(){return require('./b.js').result + abc}
					"""
					"b.js": """
						var def;
						exports.result = def = 200;
						exports.combined = function(){return require('./a.js').result + def}
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.typeOf context.aaa, 'object'
				assert.typeOf context.aaa.result, 'number'
				assert.equal context.aaa.result, 100
				assert.equal context.bbb.result, 200
				assert.equal context.aaa.combined(), 300 
				assert.equal context.bbb.combined(), 300
	

	test "are supported between (3+)-chain imported modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						aaa = import './a.js';
						//bbb = import './b.js';
						//ccc = import './c.js';
						//ddd = import './d.js';
					"""
					"a.js": """
						module.exports = 'aaa-'+require('./b.js')
					"""
					"b.js": """
						module.exports = 'bbb-'+require('./c.js')
					"""
					"c.js": """
						module.exports = 'ccc-'+require('./d.js')
					"""
					"d.js": """
						module.exports = 'ddd-'+require('./a.js')
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.aaa, 'aaa-bbb-ccc-ddd-[object Object]'
	

	test "are supported between entry file and imported modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						var TheLib = new function(){
							this.version = '14';
							this.hyperbole = function(){return this.version*100}
						}
						module.exports = TheLib;
						TheLib.version = (import './a.js')()+'.'+(import './b.js');
						theResult = TheLib.version
					"""
					"a.js": """
						module.exports = function(){return parseFloat(require('./main').version[0]) * 2}
					"""
					"b.js": """
						module.exports = parseFloat(require('./main').version[1]) * require('./main').hyperbole() + require('./a')()
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.theResult, '2.5602'
	

	test "inline imports will be transformed to modules", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						var TheLib = new function(){
							this.version = '14';
							this.hyperbole = function(){return this.version*100}
						}
						module['export'+'s'] = TheLib
						TheLib.version = (import './a.js')()+'.'+(import './b.js');
						TheLib
					"""
					"a.js": """
						aaa = function(){return parseFloat(require('./main').version[0]) * 2}
					"""
					"b.js": """
						parseFloat(require('./main').version[1]) * require('./main').hyperbole() + require('./a')()
					"""

			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({context, result})->
				assert.equal result.version, '2.5602'


	test.skip "es6 destructing imports should be live", ()->;








