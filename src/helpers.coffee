fs = require 'fs'
path = require 'path'
regEx = require './regex'

helpers = 
	getNormalizedDirname: (inputPath)-> path.normalize( path.dirname( path.resolve(inputPath) ) )

	commentOut: (line, file)-> if file.isCoffee then "\# #{line}" else "// #{line}"

	testForComments: (line, file)-> if file.isCoffee then line.includes('#') else line.includes('//')

	normalizeFilePath: (inputPath, context)->
		pathWithoutQuotes = inputPath.replace /['"]/g, '' # Remove quotes form pathname
		pathWithContext = path.normalize context+'/'+pathWithoutQuotes

		return pathWithContext



	testConditions: (allowedConditions, conditionsString)->
		conditions = conditionsString.split(/,\s?/).filter (nonEmpty)-> nonEmpty

		for condition in conditions
			return false if not allowedConditions.includes(condition)

		return true



module.exports = helpers