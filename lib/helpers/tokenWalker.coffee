
module.exports = class TokenWalker
	Object.defineProperty @::, 'current',
		get: ()-> @_current
		set: (current)-> current.value ?= current.type.label; @_current = current
	
	constructor: (@tokens, @lines, @callback)->
		@index = 0
		@results = []
		@_current = null

	prev: ()->
		@current = @tokens[--@index]

	next: ()->
		@current = @tokens[++@index] or {}

	nextUntil: (stopAt, invalidValue, invalidType)->
		pieces = []
		while @next().value isnt stopAt
			pieces.push(@current)
			
			if @current.value is invalidValue or @current.type.label is invalidType
				throw @newError()

		return pieces


	invoke: (@current, index)->
		@index = index
		result = @callback(@current, @index)


		if result
			result.tokenRange[0] = index
			result.tokenRange[1] = @index
			@results.push(result)
		
		return


	finish: ()->
		results = @results
		delete @current
		delete @results
		delete @callback
		return results


	newError: ()->
		err = new Error "unexpected '#{@current.value}'"
		err.token = @current
		err.name = 'TokenError'
		err.stack = err.stack.lines().slice(1).join('\n')
		return err


	# storeDecs: (store)->
	# 	items = @nextUntil '=', 'from', 'string'

	# 	items.reduce (store, token, index)->
	# 		if token.type.label is 'name' and token.value isnt 'as'
	# 			if items[index-1]?.value is 'as'
	# 				store[items[index-2].value] = token.value
	# 			else
	# 				store[token.value] = token.value
	# 		return store
		
	# 	, store


	storeMembers: (store)->
		items = @nextUntil '}', 'from', 'string'

		items.reduce (store, token, index)->
			if token.type.label is 'name' and token.value isnt 'as'
				if items[index-1]?.value is 'as'
					store[items[index-2].value] = token.value
				else
					store[token.value] = token.value
			return store
		
		, store


	handleMemebers: (output)->
		switch @current.value
			when '*'
				if @next().value is 'as'
					output.alias = @current.value

			when '{'
				@storeMembers(output.members ?= Object.create(null))

			when '['
				output.conditions = @nextUntil(']', 'from', 'string').map('value').exclude(',')
	

	handleDefault: (output)->
		output.members ?= {}
		output.members.default = @current.value


