matchNestingStatement = (statement, candidates)->
	if match = findNester(statement, candidates)
		match.nested ||= []
		match.nested.push statement

	return match


findNester = (statement, candidates)->
	for candidate in candidates
		if candidate.range.start <= statement.range.start <= candidate.range.end
			return candidate
	
	return false


module.exports = matchNestingStatement