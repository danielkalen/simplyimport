chalk = require 'chalk'
stackFilter = require 'stack-filter'
stackFilter.filters.push('bluebird', 'escodegen', 'esprima', 'mocha', 'timers', 'events')

filter = (stack, spacing)->
	stackFilter.filter(stack, process.cwd())
		.map (line)-> "#{spacing}#{chalk.dim line}"
		.join '\n'

module.exports = (prefix='', err)->
	err = prefix if not err
	err.message = """
		#{module.exports.message err, prefix}
		#{filter(err.stack, '\t')}
	"""
	err.stack = ''
	return err

module.exports.message = (err, prefix)-> 
	if prefix
		"#{prefix}: #{chalk.red err.message}"
	else
		chalk.red err.message


module.exports.stack = (stack)->
	filter(stack, '  ')