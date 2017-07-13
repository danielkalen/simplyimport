REGEX = require '../constants/regex'
extend = require 'extend'
PLACEHOLDER = {type:{}}
VALID_PUNCTUATORS = [',','.']
VALID_KEYWORDS = ['function','new','class','in','instanceof','typeof','void','delete']

module.exports = class TokenWalker
	Object.defineProperty @::, 'current',
		get: ()-> @_current
		set: (current)->
			if current.type.label is 'name' and current.value is 'let'
				current = extend true, current, type:{label:'let', keyword:'let'}
			current.value ?= current.type.label; @_prev = @_current; @_current = current
	
	constructor: (@tokens, @lines, @callback)->
		@index = 0
		@results = []
		@_current = null
		@_prev = PLACEHOLDER

	prev: ()->
		@current = @tokens[--@index]

	next: ()->
		@current = @tokens[++@index] or PLACEHOLDER

	nextUntil: (stopAt, invalid)->
		pieces = []
		while @next().value isnt stopAt
			pieces.push(@current)
			
			if invalid(@current, @_prev)
				throw @newError()

		return pieces


	invoke: (@current, index)->
		@index = index
		result = @callback(@current, @index)


		if result and typeof result is 'object'
			result.tokenRange.start = index
			result.tokenRange.end = @index
			@results.push(result)
		
		return


	finish: ()->
		results = @results
		delete @current
		delete @results
		delete @callback
		return results


	newError: (expecting)->
		msg = "unexpected '#{@current.value}'"
		msg += " (expecting '#{expecting}')"
		err = new Error(msg)
		err.token = @current
		err.name = 'TokenError'
		err.stack = err.stack.split('\n').slice(1).join('\n')
		return err


	storeDecs: (store)->
		prevKeyword = currentAssignment = prevWasBracket = null
		currentBrackets = []

		hasNewLine = ()=>
			prevLine = @lines.locationForIndex(@_prev.end)?.line
			currentLine = @lines.locationForIndex(@current.start)?.line
			return currentLine isnt prevLine

		while @next().type.label and @current.type.label isnt 'eof'
			isStatementEnd = hasNewLine() and not prevWasBracket and not VALID_PUNCTUATORS.includes(@_prev.value) and not VALID_KEYWORDS.includes(prevKeyword)
			prevWasBracket = false
			
			switch
				when REGEX.bracketStart.test(@current.value) and @current.type.label isnt 'string' and not isStatementEnd
					currentBrackets.push(prevWasBracket=@current.value)
					continue
				
				when REGEX.bracketEnd.test(@current.value)
					last = currentBrackets.last()
					if  last is '[' and @current.value is (expected=']') or
						last is '{' and @current.value is (expected='}') or
						last is '(' and @current.value is (expected=')')
							currentBrackets.pop()
					else
						throw @newError(expected)

					continue

				
				when currentBrackets.length is 0 then switch
					when @current.type.isAssign and not currentAssignment
						currentAssignment = @_prev.value
						store[currentAssignment] = {start:@_prev.start}

					when isStatementEnd #and not currentAssignment
						return @prev()
					
					when currentAssignment
						store[currentAssignment].end = @current.end
						prevKeyword = @current.value if @current.type.keyword

						switch
							when @current.value is ';'
								return
							when @current.value is ','
								store[currentAssignment].end = @_prev.end
								currentAssignment = null

					else
						throw @newError() unless @current.type.label is 'name'

		@prev() if not @current.type.label
		store[currentAssignment].end = @current.end

			

	storeMembers: (store)->
		items = @nextUntil '}', (token, prev)-> token.type.label is 'string'

		items.reduce (store, token, index)->
			isConnector = token.value is 'as' and items[index-1]?.type.label is 'name'
			if not isConnector and (token.type.label is 'name' or token.type.keyword is 'default' or token.type.keyword is 'from')
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
					output.alias = @next().value

			when '{'
				@storeMembers(output.members ?= Object.create(null))

			when '['
				invalidator = (token)-> token.type.label is 'string'
				output.conditions = @nextUntil(']', invalidator).map('value').exclude(',')
	

	handleDefault: (output)->
		output.members ?= {}
		output.members.default = @current.value


