matchNestingStatement = (statement, candidates)->
	if match = findNester(statement, candidates)
		match.nested ||= []
		match.nested.push prepareEntry(statement, match)

	return match


findNester = (statement, candidates)->
	for candidate in candidates
		if candidate.range.start <= statement.range.start <= candidate.range.end
			return candidate
	
	return false


prepareEntry = (statement, nester)->
	start = statement.range.start - nester.dec.start
	end = statement.range.end - nester.dec.start
	return {statement, dec:statement.dec, range:{start, end}}



module.exports = matchNestingStatement