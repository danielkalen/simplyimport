helpers = require '../helpers'
debug = require('../debug')('simplyimport:file')


exports.getStatementSource = (statement)->
	range = statement.range
	
	for candidate,i in @inlineStatements when candidate.kind isnt 'excluded'
		offset = candidate.offset
		candidateRange = candidate.range
		candidateRange = start:candidateRange.start+offset, end:candidateRange.end+offset
		
		if candidateRange.start <= statement.range.start and statement.range.end <= candidateRange.end
			statement.range.orig = candidate
			return candidate.target.getStatementSource(statement)
	
	return @



exports.offsetStatements = (offset)->
	for statement in @statements
		if statement.range.start >= offset.start
			length = offset.end - offset.start
			statement.range.start += length
			statement.range.end += length
	return

exports.resolveNestedStatements = ()->
	exportStatements = @statements.filter({statementType:'export'})
	importStatements = @statements.filter({statementType:'import'})
	for statement in importStatements when statement.node
		statement.isNested = helpers.matchNestingStatement(statement, exportStatements)
	return









