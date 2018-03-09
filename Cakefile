global.Promise = require('bluebird').config warnings:false, longStackTraces:process.env.DEBUG
fs = require 'fs-jetpack'
chalk = require 'chalk'
execa = require 'execa'
packageInstall = require 'package-install'
Path = require 'path'
mocha = Path.resolve 'node_modules','mocha','bin','mocha'
nyc = Path.resolve 'node_modules','nyc','bin','nyc.js'
process.env.SOURCE_MAPS ?= 1
testModules = [
	'mocha@3.5.3', 'chai', 'nock', 'browserify', 'babelify',
	'babel-preset-es2015-script', 'envify', 'es6ify', 'brfs',
	'axios', 'moment', 'timeunits', 'yo-yo', 'smart-extend',
	'p-wait-for', 'source-map-support', 'xmlhttprequest',
	'redux', 'lodash', 'leakage', 'formatio', 'chai-as-promised',
	'location', 'pug', 'node-sass', 'html2json', 'modcss', ['traceur', ()-> parseFloat(process.version.slice(1)) < 6.2]]


task 'test', ()->
	Promise.resolve()
		.then ()-> packageInstall testModules
		.then ()-> runTests()
		.catch handleError

task 'test:debug', ()->
	Promise.resolve()
		.then ()-> packageInstall testModules
		.then ()-> runTests(['--inspect-brk'])
		.catch handleError



task 'coverage', ()->
	Promise.resolve()
		.then ()-> packageInstall ['nyc', 'badge-gen'].concat(testModules)
		.then ()-> [mocha].concat prepareOptions ['--require','coffee-coverage/register-istanbul']
		.then (options)-> execa nyc, covReporters.concat(options), {stdio:'inherit'}
		.catch handleError

task 'bench', ()->
	require './bench'



handleError = (err)-> unless err.message.startsWith('Command failed')
	console.error chalk.red err.message

runTests = (options)->
	options = prepareOptions(options)
	execa mocha, options, {stdio:'inherit'}

prepareOptions = (options=[])->
	mochaOptions.concat(options).concat 'test/test.coffee'

mochaOptions = [
	'--bail'
	'-u','tdd'
	'--compilers','coffee:coffee-register'
	'--slow',(if process.env.DEBUG then '7000' else '1500')
	'--timeout',(if process.env.DEBUG then '20000' else '8000')
]

covReporters = [
	'--reporter','text'
	'--reporter','html'
]
