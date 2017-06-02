global.Promise = require 'bluebird'
Promise.config longStackTraces:true if process.env.CI 
promiseBreak = require 'promise-break'
spawn = require('child_process').spawn
fs = require 'fs-jetpack'
Path = require 'path'
testModules = ['browserify', 'axios', 'babelify', 'babel-preset-es2015-script', 'jquery-selector-cache', 'timeunits', 'yo-yo', 'envify', 'icsify', 'smart-extend', 'p-wait-for', 'source-map-support']
coverageModules = ['istanbul', 'badge-gen', 'coffee-coverage']
process.env.SOURCE_MAPS = 1


task 'test', ()->
	Promise.resolve()
		.then ()-> testModules.every (testModule)-> fs.exists Path.resolve('node_modules',testModule)
		.then (installed)-> promiseBreak() if installed
		.then ()-> installModules(testModules)
		.catch promiseBreak.end
		.then runTests



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
				exclude: ['/test','/scripts','/node_modules','/.git','/.config','/coverage']
				covreageVar: covreageVar
				writeOnExit: if coverageVar? then Path.resolve('coverage','coverage-coffee.json') else null
				initAll: true

			runTests()

		.then ()->
			istanbul = require 'istanbul'
			Report = istanbul.Report
			collector = new istanbul.Collector
			reporter = new istanbul.Reporter
				dir: Path.resolve('coverage')
				root: Path.resolve()
				formats: ['html', 'lcov']

			collector.add fs.read(Path.resolve('coverage','coverage-coffee.json'), 'json')
			new Promise (resolve, reject)->
				reporter.write collector, false, (err)->
					if err then reject(err) else resolve()

		.then ()-> console.log 'Done'




installModules = ()-> new Promise (resolve, reject)->
	install = spawn('npm', ['install', '--no-save', testModules...], {stdio:'inherit'})
	install.on 'error', reject
	install.on 'close', resolve


runTests = ()->
	mocha = new (require 'mocha')
		ui: 'tdd'
		bail: not process.env.CI
		timeout: 8000
		slow: 1500
		userColors: true

	mocha.addFile Path.join('test','test.coffee')
	mocha.run (failures)->
		process.on 'exit', ()-> process.exit(failures)


