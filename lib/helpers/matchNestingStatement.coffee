matchNestingStatement = (statement, candidates)->
	match = findNester(statement, candidates)

	if match
		match.nestedStatements.push prepareEntry(statement, match)

	return match


findNester = (statement, candidates)->
	for candidate in candidates
		if candidate.range.start <= statement.range.start <= candidate.range.end
			return candidate
	
	return false


findDeclaration = (statement, nester)->
	decs = Object.keys(nester.decs)

	for dec in decs
		value = nester.decs[dec]

		if value.range.start <= statement.range.start <= value.range.end
			return dec


prepareEntry = (statement, nester)->
	dec = findDeclaration(statement, nester)
	decRange = nester.decs[dec].range
	start = statement.range.start - decRange.start
	end = statement.range.end - decRange.start
	return {statement, dec, range:{start, end}}



module.exports = matchNestingStatement