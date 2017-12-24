parser = require '../external/parser'
vm = require 'vm'
helpers = require './'
GLOBALS = require '../constants/globals'
ConditionalError = 'ConditionalError'

matchConditional = (file, start, end)->
	{options} = file.task
	{env, target} = options
	jsString = constructScript(start[2], target)

	result = runCheck(jsString, {env})
	if result instanceof Error
		file.task.emit 'ConditionalError', file, result
		return false
	
	return result



runCheck = (jsString, context)->
	try
		return vm.runInNewContext(jsString, context)
	catch err
		return err


tokenize = ((code)->
	Array.from require('acorn').tokenizer code
).memoize()


constructScript = ((code, target)->
	tokens = tokenize(code)
	output = ''
	
	for token,i in tokens
		token.value ?= token.type.label
		
		switch token.type.label
			when 'name'
				if tokens[i-1]?.value is '.' or GLOBALS.includes(token.value)
					output += token.value
				else if token.value is 'BUNDLE_TARGET'
					output += " '#{target}'"
				else
					output += " env['#{token.value}']"

			when 'string'
				output += "'#{token.value}'"

			when 'regexp'
				output += "#{token.value.value}"

			when '=','==/!=','||','|','&&','&'
				output += ' ' + switch token.value
					when '=','==','===' then '=='
					when '!=','!==' then '!='
					when '||','|' then '||'
					when '&&','&' then '&&'
					else token.value
			else
				if token.type.keyword
					output += " #{token.value} "
				else
					output += token.value


	return output
).memoize()


module.exports = matchConditional