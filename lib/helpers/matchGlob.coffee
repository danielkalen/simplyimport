micromatch = require 'micromatch'

module.exports = matchGlob = (config, globs)->
	matchingGlob = null
	opts = matchBase:true
	
	for glob in globs
		if micromatch.isMatch(config.pathAbs, glob, opts) or
			micromatch.isMatch(config.pathAbs, glob) or
			micromatch.isMatch(config.pathRel, glob) or
			micromatch.isMatch(config.path, glob) or
			micromatch.isMatch(config.suppliedPath, glob, opts)
				matchingGlob = glob

	return matchingGlob