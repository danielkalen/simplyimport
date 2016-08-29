chalk = require 'chalk'

module.exports = 
	'info': chalk.bgBlack.blue('INFO')
	'warn': chalk.bgBlack.yellow('WARN')
	'error': chalk.bgBlack.red('ERR')