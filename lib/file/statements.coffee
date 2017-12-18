helpers = require '../helpers'
debug = require('../debug')('simplyimport:file')


exports.getStatementSource = (statement)->
	range = statement.range
	
	for candidate,i in @inlineStatements when candidate.kind isnt 'excluded'		
		if candidate.rangeNew.start <= statement.range.start and statement.range.end <= candidate.rangeNew.end
			statement.range.orig = candidate
			return candidate.target.getStatementSource(statement)
	
	return @


exports.resolveNestedStatements = ()->
	exportStatements = @statements.filter({statementType:'export'})
	importStatements = @statements.filter({statementType:'import'})
	for statement in importStatements when statement.node
		statement.isNested = helpers.matchNestingStatement(statement, exportStatements)
	return









