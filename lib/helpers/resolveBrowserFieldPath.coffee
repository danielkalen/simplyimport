Path = require 'path'

module.exports = (pkgFile, suppliedPath, basedir)->
	targetPath = Path.join(basedir, suppliedPath)
	relPath = Path.relative basedir, targetPath
	target = Path.parse targetPath
	target.dir = '' if target.dir is '.'

	return pkgFile.browser[suppliedPath] if pkgFile.browser[suppliedPath]
	return pkgFile.browser[relPath] if pkgFile.browser[relPath]


	for candidatePath,value of pkgFile.browser
		candidatePath = Path.resolve pkgFile.dirPath, candidatePath
		candidate = Path.parse(candidatePath)
		candidate.dir = '' if candidate.dir is '.'
		
		switch
			when candidate.dir isnt target.dir
				continue
			when target.ext
				return value if candidate.base is target.base
			else
				return value if candidate.name is target.name

	return