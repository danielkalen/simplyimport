TokenWalker = require './tokenWalker'

walkTokens = (tokens, content, valueToStopAt, cb)->
	walker = new TokenWalker(tokens, content, cb)
	
	for token,i in tokens when matchValue(token, valueToStopAt)
		walker.invoke(token, i)
	
	return walker.finish()

matchValue = (token, value)-> switch
	when not value
		return true
	
	when typeof value is 'string'
		return token.value is value
	
	when Array.isArray(value)
		return value.some (item)-> token.value is item


module.exports = walkTokens