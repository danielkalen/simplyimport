REGEX = require '../constants/regex'
Path = require './path'

normalizeTargetPath = (path, importer, removeQuotes)->
	result = path.replace REGEX.pathPlaceholder, (original, placeholder)->
		switch
			when placeholder is 'CWD' then process.cwd()
			when placeholder is 'ROOT' then importer.pkg.dirPath
			when placeholder is 'BASE'
				if importer.task.entryFile.pkg is importer.pkg # same package
					importer.task.entryFile.context
				else
					importer.pkgEntry.dir

			when custom = importer.options.placeholder[placeholder]
				Path.resolve(importer.pkg.dirPath, custom)
			
			else original

	result = result.removeAll(REGEX.quotes) if removeQuotes
	return result.trim()




module.exports = normalizeTargetPath