global.Promise = require 'bluebird'
Promise.config longStackTraces:true if process.env.CI or true
promiseBreak = require 'promise-break'
spawn = require('child_process').spawn
fs = require 'fs-jetpack'
Path = require 'path'
testModules = ['streamify-string', 'browserify', 'axios', 'babelify', 'babel-preset-es2015-script', 'jquery-selector-cache', 'timeunits', 'yo-yo', 'envify']
coverageModules = ['istanbul', 'badge-gen', 'coffee-coverage']


task 'test', ()->
	Promise.resolve()
		.then ()-> testModules.every (testModule)-> fs.exists Path.resolve('node_modules',testModule)
		.then (installed)-> promiseBreak() if installed
		.then ()-> installModules(testModules)
		.catch promiseBreak.end
		.then ()->
			mocha = new (require 'mocha')
				ui: 'tdd'
				bail: not process.env.CI
				timeout: 8000
				slow: 1500
				userColors: true

			mocha.addFile Path.join('test','spec.coffee')
			mocha.run (failures)->
				process.on 'exit', ()-> process.exit(failures)


task 'coverage', ()->
	Promise.resolve()
		.then ()-> covreageModules.every (covreageModule)-> fs.exists Path.resolve('node_modules',covreageModule)
		.then (installed)-> promiseBreak() if installed
		.then ()-> installModules(coverageModules)
		.catch promiseBreak.end
		.then ()->
			coffeeCoverage = require 'coffee-coverage'
			coverageVar = coffeeCoverage.findIstanbulVariable()
			
			coffeeCoverage.register
				instrumentor: 'istanbul'
				basePath: process.cwd()
				exclude: ['/test','/scripts','/node_modules','/.git','/.config','/covreage']
				covreageVar: covreageVar
				writeOnExit: if coverageVar? then Path.resolve('coverage','coverage-coffee.json')
				initAll: true




installModules = ()-> new Promise (resolve, reject)->
	install = spawn('npm', ['install', testModules...], {stdio:'inherit'})
	install.on 'error', reject
	install.on 'close', resolve






