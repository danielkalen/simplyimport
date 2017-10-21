Path = require './path'
extend = require 'extend'

resolvePlaceholders = (file)->
	entryFile = file.task.entryFile or file
	entryPlaceholders = resolvePaths(file.task.options.placeholder, entryFile.pkg.dirPath)
	selfPlaceholders = file.pkg.simplyimport?.placeholder

	if selfPlaceholders and file.pkg isnt entryFile.pkg
		return extend {}, entryPlaceholders, resolvePaths(selfPlaceholders, file.pkg.dirPath)
	else
		return entryPlaceholders


resolvePaths = (paths, dir)->
	output = {}
	
	for path,value of paths
		output[path] = Path.resolve(dir, value)

	return output



module.exports = resolvePlaceholders