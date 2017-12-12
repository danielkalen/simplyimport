REGEX = require '../constants/regex'
extend = require 'extend'
stringPos = require 'string-pos'
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
	
	constructor: (@tokens, @content, @callback)->
		@index = 0
		@results = []
		@_current = null
		@_prev = PLACEHOLDER

	prev: ()->
		@current = @tokens[--@index]

	next: ()->
		@current = @tokens[++@index] or PLACEHOLDER


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

