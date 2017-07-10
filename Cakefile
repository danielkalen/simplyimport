global.Promise = require 'bluebird'
Promise.config longStackTraces:true if process.env.DEBUG
promiseBreak = require 'promise-break'
spawn = require('child_process').spawn
fs = require 'fs-jetpack'
chalk = require 'chalk'
Path = require 'path'
process.env.SOURCE_MAPS ?= 1
coverageModules = ['istanbul', 'badge-gen', 'coffee-coverage']
testModules = [
	'mocha', 'chai', 'browserify', 'babelify', 'formatio',
	'babel-preset-es2015-script', 'envify', 'es6ify', 'brfs',
	'axios', 'moment', 'timeunits', 'yo-yo', 'smart-extend',
	'p-wait-for', 'source-map-support', 'xmlhttprequest',
	'location', 'pug', 'node-sass', 'html2json', 'modcss', ['traceur', ()-> parseFloat(process.version.slice(1)) < 6.2]]


task 'test', ()->
	Promise.resolve()
		.then ()-> testModules.filter (module)-> not moduleInstalled(module)
		.tap (missingModules)-> promiseBreak() if missingModules.length is 0
		.tap (missingModules)-> installModules(missingModules)
		.catch promiseBreak.end
		.then runTests



task 'coverage', ()->
	Promise.resolve()
		.then ()-> coverageModules.filter (module)-> not moduleInstalled(module)
		.tap (missingModules)-> promiseBreak() if missingModules.length is 0
		.tap (missingModules)-> installModules(missingModules)
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




installModules = (targetModules)-> new Promise (resolve, reject)->
	targetModules = targetModules
		.filter (module)-> if typeof module is 'string' then true else module[1]()
		.map (module)-> if typeof module is 'string' then module else module[0]
	
	return resolve() if not targetModules.length
	console.log "#{chalk.yellow('Installing')} #{chalk.dim targetModules.join ', '}"
	
	install = spawn('npm', ['install', '--no-save', '--no-purne', targetModules...], {stdio:'inherit'})
	install.on 'error', reject
	install.on 'close', resolve


moduleInstalled = (targetModule)->
	targetModule = targetModule[0] if typeof targetModule is 'object'
	pkgFile = Path.resolve('node_modules',targetModule,'package.json')
	exists = fs.exists(pkgFile)
	
	if exists and targetModule is 'source-map-support'
		version = fs.read(pkgFile, 'json').version
		exists = parseInt(version.split('.')[1]) >= 4

	return exists


runTests = ()->
	mocha = new (require 'mocha')
		ui: 'tdd'
		bail: not process.env.DEBUG
		timeout: if process.env.DEBUG then 20000 else 8000
		slow: if process.env.DEBUG then 7000 else 1500
		userColors: true

	mocha.addFile Path.join('test','test.coffee')
	mocha.run (failures)->
		process.on 'exit', ()-> process.exit(failures)


