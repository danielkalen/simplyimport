
module.exports = class TokenWalker
	constructor: (@tokens, @lines, @callback)->
		@index = 0
		@current = null
		@results = []

	prev: ()->
		@current = @tokens[--@index]

	next: ()->
		@current = @tokens[++@index] or {}

	nextUntil: (stopAt, invalidValue, invalidType)->
		pieces = []
		while @next().value isnt stopAt
			pieces.push(@current)
			
			if @current.value is invalidValue or @current.type is invalidType
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
		loc = @lines.locationForIndex(@current.range[0])
		err = new Error "unexpected #{@current.type} '#{@current.value}' at line #{loc.line+1}:#{loc.column}"
		err.name = 'TokenError'
		err.stack = err.stack.lines().slice(1).join('\n')
		return err


	storeMembers: (store)->
		items = @nextUntil '}', 'from', 'String'

		items.reduce (store, token, index)->
			if token.type.label is 'name' and token.value isnt 'as'
				if items[index-1].value is 'as'
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
				output.conditions = @nextUntil(']', 'from', 'String').map('value').exclude(',')
	

	handleDefault: (output)->
		output.members ?= {}
		output.members.default = @current.value


