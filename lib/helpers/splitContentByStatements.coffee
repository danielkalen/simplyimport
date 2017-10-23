splitContentByStatements = (content, statements)->
	if not statements.length
		return [content]
	else
		parts = []
		contentIndex = 0
		statements = statements.sortBy('range.start')
		
		for statement,index in statements
			continue if statement.isNested
			parts.push content.slice(contentIndex, statement.range.start)
			parts.push statement
			contentIndex = statement.range.end

		parts.push content.slice(contentIndex)

		return parts


module.exports = splitContentByStatements