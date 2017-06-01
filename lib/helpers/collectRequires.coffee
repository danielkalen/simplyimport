helpers = require('./')

module.exports = collectRequires = (tokens, lines)->
	@walkTokens tokens, lines, 'require', ()->
		@next()
		@next() if @current.type is 'Punctuator'
		return if @current.type isnt 'String'
		output = helpers.newImportStatement()
		output.target = @current.value.removeAll(REGEX.quotes).trim()

		return output if @next().value isnt ','
		return output if @next().value isnt 'string'
		output.members ?= {}
		output.members.default = @current.value.removeAll(REGEX.quotes).trim()

		return output if @next().value isnt ','
		return output if @next().value isnt 'string'
		output.members ?= {}
		members = @current.value.removeAll(REGEX.quotes).trim()

		if members.startsWith '*'
			split = members.split(REGEX.es6membersAlias)
			output.alias = split[1]
		else
			members.split(/,\s*/).forEach (memberSignature)->
				split = memberSignature.split(REGEX.es6membersAlias)
				output.members[split[0]] = split[1] or split[0]

		return output