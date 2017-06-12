chalk = require 'chalk'
LinesAndColumns = require('lines-and-columns').default

module.exports = (file, posStart, posEnd=posStart+1)->
	lines = new LinesAndColumns(file.content)
	loc = lines.locationForIndex(posStart)
	line = file.content.lines()[loc.line]
	line = line.slice(0, Math.min(10,process.stderr.columns)) if line.length > process.stderr.columns
	caretCount = Math.min line.length-loc.column, posEnd-posStart
	loc.line += 1
	
	"""
		\n
		#{chalk.dim file.path+':'+loc.line+':'+loc.column} -
			#{line}
			#{' '.repeat(loc.column)}#{chalk.red '^'.repeat(caretCount)}
	"""