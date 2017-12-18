chalk = require 'chalk'
stackFilter = require 'stack-filter'
stackFilter.filters.push('bluebird', 'fs-jetpack', 'astring', 'acorn', 'mocha', 'timers', 'events')

filter = (stack, spacing)->
	stackFilter.filter(stack, process.cwd())
		.map (line)-> "#{spacing}#{chalk.dim line}"
		.filter (line,index)-> if index > 0 then 1 else not line.includes('Error:')
		.join '\n'


module.exports = (prefix='', err, noColor)->
	if not err
		err = prefix
		prefix = ''

	return err if err.formatted

	if err.stack and err.message and err.stack.includes(err.message)
		err.message = err.stack.slice(0, err.stack.indexOf(err.message)+err.message.length)
		err.stack = err.stack.slice(err.message.length)
	
	err.message += "\n#{err.annotated}" if err.annotated and not err.message.includes(err.annotated)
	err.message = """
		#{module.exports.message err, prefix, noColor}
		#{filter(err.stack, '\t')}
	"""
	err.stack = ''
	Object.defineProperty err, 'formatted', value:true
	return err


module.exports.message = (err, prefix, noColor)-> 
	if prefix
		message = if noColor then err.message else chalk.red(err.message)
		"#{prefix}: #{message}"
	else
		chalk.red err.message


module.exports.stack = (stack)->
	filter(stack, '  ')