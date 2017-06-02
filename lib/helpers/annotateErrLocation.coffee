chalk = require 'chalk'
LinesAndColumns = require('lines-and-columns').default

module.exports = (file, codeIndex)->
	lines = new LinesAndColumns(file.content)
	loc = lines.locationForIndex(codeIndex)
	line = file.content.lines()[loc.line]
	line = line.slice(0, Math.min(10,process.stderr.columns)) if line.length > process.stderr.columns
	
	"""
		\n
		#{chalk.dim file.path+':'+loc.line+':'+loc.column} -
			#{line}
			#{' '.repeat(loc.column)}#{chalk.red '^'}
	"""