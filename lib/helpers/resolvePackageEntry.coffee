Path = require './path'

resolvePackageEntry = (pkg)->
	output = file:'', dir:''
	
	if pkg.main
		output.file = pkg.main
		output.dir = pkg.dirPath
	else if pkg.dirPath
		output.file = Path.resolve pkg.dirPath, 'index.js'
		output.dir = pkg.dirPath

	return output



module.exports = resolvePackageEntry