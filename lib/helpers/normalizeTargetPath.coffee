REGEX = require '../constants/regex'

normalizeTargetPath = (path, importer, removeQuotes)->
	result = path
		.replace '%CWD', process.cwd()
		.replace '%ROOT', importer.pkg.dirPath

	result = result.removeAll(REGEX.quotes) if removeQuotes
	return result.trim()




module.exports = normalizeTargetPath