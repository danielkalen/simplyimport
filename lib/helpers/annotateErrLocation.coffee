chalk = require 'chalk'
LinesAndColumns = require('lines-and-columns').default

module.exports = (file, posStart, posEnd=posStart+1)->
	try
		terminalLen = process.stderr.columns
		terminalLen -= 1 if terminalLen % 2
		lines = new LinesAndColumns(file.content)
		loc = lines.locationForIndex(posStart)
		line = lineOrig = file.content.split('\n')[loc.line]
		padding = loc.column

		if terminalLen and terminalLen < line.length
			middle = loc.column
			lineStart = Math.max 0, middle-(terminalLen/2)
			lineEnd = middle+(terminalLen/2)
			line = line.slice lineStart, lineEnd
			padding = terminalLen/2
		
		caretCount = Math.min line.length-padding, posEnd-posStart
		loc.line += 1

	catch
		loc = line:0, column:0
		caretCount = 0

	"""
		\n
		#{chalk.dim file.path+':'+loc.line+':'+loc.column} -
			#{line}
			#{' '.repeat(padding)}#{chalk.red '^'.repeat(caretCount)}
	"""
