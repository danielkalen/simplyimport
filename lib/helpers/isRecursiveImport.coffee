
module.exports = (mainStatement)->
	mainStatement.target.importStatements.some (statement)->
		statement.target is mainStatement.source