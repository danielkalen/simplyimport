micromatch = require 'micromatch'
MATCH_BASE = matchBase: true

module.exports = matchGlob = (config, globs)->
	matchingGlob = null
	globs = [globs] if not Array.isArray(globs)
	if typeof config is 'string'
		config = pathAbs:config, pathRel:config, path:config, suppliedPath:config
	
	for glob in globs
		if  glob is config.pathAbs or
			micromatch.isMatch(config.pathAbs, glob, MATCH_BASE) or
			micromatch.isMatch(config.pathAbs, glob) or
			micromatch.isMatch(config.pathRel, glob) or
			micromatch.isMatch(config.path, glob) or
			micromatch.isMatch(config.suppliedPath, glob, MATCH_BASE)
				matchingGlob = glob

	return matchingGlob