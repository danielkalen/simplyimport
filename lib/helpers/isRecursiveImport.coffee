
module.exports = (mainStatement)->
	mainStatement.target.statements
		.filter({statementType:'import'})
		.some (statement)-> statement.target is mainStatement.source