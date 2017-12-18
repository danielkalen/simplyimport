chalk = require 'chalk'
printCode = require 'print-code'
stringPos = require 'string-pos'

module.exports = (file, posStart, posEnd=posStart+1)->
	{content} = file
	start = stringPos(content, posStart)
	end = stringPos(content, posEnd)
	
	codeHighlight =
		printCode(file.content)
			.highlightRange(start, end)
			.slice(start.line-1, end.line+2)
			.color 'red'
			.arrow_mark start.line, start.column+1
			.get()

	"""
		\n
		#{chalk.dim file.path+':'+start.line+':'+start.column} -
		#{codeHighlight}
	"""