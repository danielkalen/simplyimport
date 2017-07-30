helpers = require './'
Path = require 'path'

module.exports = (suppliedPath, importerDir, pkgDir, aliases)->
	targetPath = Path.resolve(importerDir, suppliedPath)
	relPath = Path.relative importerDir, targetPath

	return aliases[suppliedPath] if typeof aliases[suppliedPath] is 'string'
	return aliases[relPath] if typeof aliases[relPath] is 'string'

	for candidatePath,value of aliases
		if helpers.isMatchPath(targetPath, Path.resolve(pkgDir, candidatePath))
			return value

	return