globMatch = require 'micromatch'

module.exports = matchFileSpecificOptions = (config, specificOptions)-> switch
	when specificOptions[config.suppliedPath]
		return specificOptions[config.suppliedPath]
	
	when specificOptions[config.pathBase]
		return specificOptions[config.pathBase]
		
	else
		matchingGlob = null
		opts = matchBase:true
		
		for glob of specificOptions
			if globMatch.isMatch(config.pathAbs, glob, opts) or
				globMatch.isMatch(config.pathAbs, glob) or
				globMatch.isMatch(config.path, glob) or
				globMatch.isMatch(config.suppliedPath, glob, opts)
					matchingGlob = glob

		return specificOptions[matchingGlob] or {}