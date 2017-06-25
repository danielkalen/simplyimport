# yargs = require 'yargs'
# 	.usage(require './usage')
# 	.options(require './options')
# 	.help('h')
# 	.wrap(require('yargs').terminalWidth())
# 	.version(()-> require('../../package.json').version)
# args = yargs.argv
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
program = require('commander').version require('../../package.json').version
commands = require './commands'
program.specified = false
require './help'


for command in commands
	program.command(command.command...)

	for option in command.options
		program.option(option...)

	program.action(command.action)
	

program.parse(process.argv)
program.help() if not program.specified

