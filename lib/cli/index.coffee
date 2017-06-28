Promise = require 'bluebird'
Promise.config longStackTraces:true if process.env.DEBUG
promiseBreak = require 'promise-break'
program = require('commander').version require('../../package.json').version
commands = require './commands'
program.specified = false


for command in commands
	target = program.command(command.command...)
	target.description(command.description)

	for option in command.options
		target.option(option...)

	target.action(command.action)
	


if  process.argv[2] isnt 'bundle' and
	process.argv[2] isnt 'list' and
	not process.argv.some((arg)-> arg is '-h' or arg is '--help')
		process.argv.splice 2,0,'bundle'

program.parse(process.argv)
program.help() if not program.specified

