chalk = require 'chalk'
LinesAndColumns = require('lines-and-columns').default

module.exports = (file, posStart, posEnd=posStart+1)->
	lines = new LinesAndColumns(file.content)
	loc = lines.locationForIndex(posStart)
	line = lineOrig = file.content.lines()[loc.line]
	line = line.slice(0, Math.min(10,process.stderr.columns)) if line.length > process.stderr.columns and process.stderr.columns
	caretCount = Math.min line.length-loc.column, posEnd-posStart
	loc.line += 1

	try
		return """
			\n
			#{chalk.dim file.path+':'+loc.line+':'+loc.column} -
				#{line}
				#{' '.repeat(loc.column)}#{chalk.red '^'.repeat(caretCount)}
		"""
	catch err
		console.log chalk.yellow file.path
		console.log {posStart, posEnd, loc}
		console.log {caretCount, line, lineOrig, stderr:process.stderr.columns, stdout:process.stdout.columns}
		console.log chalk.dim file.content
		# console.warn file.content.lines()
		throw err