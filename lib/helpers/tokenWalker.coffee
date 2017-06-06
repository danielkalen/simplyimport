REGEX = require '../constants/regex'
extend = require 'extend'
PLACEHOLDER = {type:{}}

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


	storeDecs: (store)->
		prevKeyword = null
		currentAssignment = null
		currentBrackets = []

		hasNewLine = ()=>
			prevLine = @lines.locationForIndex(@_prev.end).line
			currentLine = @lines.locationForIndex(@current.start).line
			return currentLine isnt prevLine

		while @next().type.label and @current.type.label isnt 'eof' then switch
			when REGEX.bracketStart.test(@current.value)
				currentBrackets.push(@current.value)
				continue
			
			when REGEX.bracketEnd.test(@current.value)
				last = currentBrackets.last()
				if  last is '[' and @current.value is ']' or
					last is '{' and @current.value is '}' or
					last is '(' and @current.value is ')'
						currentBrackets.pop()
				else
					throw @newError()

				continue

			
			when currentBrackets.length is 0 then switch
				when @current.type.isAssign and not currentAssignment
					currentAssignment = @_prev.value
					store[currentAssignment] = {start:@_prev.start}

				when hasNewLine() and @_prev.value isnt ',' and not currentAssignment
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
					# unless @current.type.label is 'name'
					# 	debugger
					# 	throw @newError()

		store[currentAssignment]?.end ?= @current.end

			

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
					output.alias = @next().value

			when '{'
				@storeMembers(output.members ?= Object.create(null))

			when '['
				output.conditions = @nextUntil(']', 'from', 'string').map('value').exclude(',')
	

	handleDefault: (output)->
		output.members ?= {}
		output.members.default = @current.value


