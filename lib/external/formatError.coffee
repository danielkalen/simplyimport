chalk = require 'chalk'
stackFilter = require 'stack-filter'
stackFilter.filters.push('bluebird', 'escodegen', 'astring', 'acorn', 'esprima', 'mocha', 'timers', 'events')

filter = (stack, spacing)->
	stackFilter.filter(stack, process.cwd())
		.map (line)-> "#{spacing}#{chalk.dim line}"
		.filter (line,index)-> if index > 0 then 1 else not line.includes('Error:')
		.join '\n'

module.exports = (prefix='', err)->
	if not err
		err = prefix
		prefix = ''

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