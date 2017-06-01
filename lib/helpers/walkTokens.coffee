

module.exports = walkTokens = (tokens, lines, valueToStopAt, cb)->
	walker = new TokenWalker(tokens, lines, cb)
	
	for token,i in tokens when (if valueToStopAt? then token.value is valueToStopAt else true)
		walker.invoke(token, i)
	
	return walker.finish()