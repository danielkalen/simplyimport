global.Promise = require('bluebird').config warnings:false, longStackTraces:process.env.DEBUG
fs = require 'fs-jetpack'
chalk = require 'chalk'
packageInstall = require 'package-install'
Path = require 'path'
process.env.SOURCE_MAPS ?= 1
testModules = [
	'mocha', 'chai', 'nock', 'browserify', 'babelify', 'formatio',
	'babel-preset-es2015-script', 'envify', 'es6ify', 'brfs',
	'axios', 'moment', 'timeunits', 'yo-yo', 'smart-extend',
	'p-wait-for', 'source-map-support', 'xmlhttprequest',
	'redux', 'lodash'
	'location', 'pug', 'node-sass', 'html2json', 'modcss', ['traceur', ()-> parseFloat(process.version.slice(1)) < 6.2]]


task 'test', ()->
	Promise.resolve()
		.then ()-> packageInstall testModules
		.then runTests



task 'coverage', ()->
	Promise.resolve()
		.then ()-> packageInstall ['istanbul', 'badge-gen', 'coffee-coverage']
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


