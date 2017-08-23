Path = require './path'
extend = require 'extend'

module.exports = (targetPath, candidatePath)->
	target = parsePath(targetPath)
	candidate = parsePath(candidatePath)

	switch
		when candidate.dir isnt target.dir
			return false
		when target.ext and candidate.ext
			return true if candidate.base is target.base
		else
			return true if candidate.name is target.name

	return false


parsePath = ((target)->
	if typeof target is 'string'
		parsed = Path.parse(target)
		parsed = extend({}, parsed, {dir:''}) if parsed.dir is '.'
		return parsed
	else
		return target
).memoize()
