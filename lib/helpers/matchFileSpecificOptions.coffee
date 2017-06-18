helpers = require './'
globMatch = require 'micromatch'

module.exports = matchFileSpecificOptions = (config, specificOptions)-> switch
	when specificOptions[config.suppliedPath]
		return specificOptions[config.suppliedPath]
	
	when specificOptions[config.pathBase]
		return specificOptions[config.pathBase]
		
	else
		matchingGlob = helpers.matchGlob config, Object.keys(specificOptions)
		return specificOptions[matchingGlob] or {}