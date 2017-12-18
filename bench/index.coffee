global.Promise = require('bluebird').config warnings:false, longStackTraces:false
SimplyImport = require '../'
chalk = require 'chalk'
bytes = require 'sugar/number/bytes'
state = {count:0, memory:process.memoryUsage()}

Promise.resolve()
	.then ()-> debugger
	.delay 200
	.then ()-> createBundle()
	.delay 200
	.then ()-> createBundle()
	.delay 200
	.then ()-> createBundle()
	.delay 200
	.then ()-> calcMemoryUsage()


createBundle = ()->	
	Promise.resolve()
		.then ()->
			console.log chalk.dim "Run ##{++state.count}"
			state.start = process.hrtime()
			SimplyImport.compile src:"module.exports = require 'crypto')"
		
		.then ()->
			duration = process.hrtime(state.start)
			duration = ((duration[0]*1e9) + duration[1]) / 1e6
			console.log chalk.green "#{duration}ms"


calcMemoryUsage = ()->
	current = process.memoryUsage()
	for key of state.memory
		console.log key, bytes(current[key] - state.memory[key])
