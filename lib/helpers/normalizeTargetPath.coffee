REGEX = require '../constants/regex'

normalizeTargetPath = (path, importer, removeQuotes)->
	result = path.replace REGEX.pathPlaceholder, (e, placeholder)->
		switch placeholder
			when 'CWD' then process.cwd()
			when 'ROOT' then importer.pkg.dirPath
			when 'BASE' then importer.task.entryFile.dirPath
			else importer.task.options.placeholder[placeholder] or e		

	result = result.removeAll(REGEX.quotes) if removeQuotes
	return result.trim()




module.exports = normalizeTargetPath