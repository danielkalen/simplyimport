fs = require 'fs'
path = require 'path'
regEx = require './regex'

helpers = 
	getNormalizedDirname: (inputPath)-> path.normalize( path.dirname( path.resolve(inputPath) ) )

	simplifyPath: (inputPath)-> inputPath.replace process.cwd()+'/', ''

	testForComments: (line, file)-> if file.isCoffee then line.includes('#') else line.includes('//')

	commentOut: (line, file, isImportLine)->
		comment = if file.isCoffee then '#' else '//'
		if isImportLine
			@commentBadImportLine(line, comment)
		else
			"#{comment} #{line}"

	commentBadImportLine: (importLine, comment)->
		importLine.replace regEx.importOnly, (importDec)-> "#{comment} #{importDec}"


	normalizeFilePath: (inputPath, context)->
		inputPath = inputPath
			.replace /['"]/g, '' # Remove quotes form pathname
			.replace /\s+$/, '' # Remove whitespace from the end of the string
		pathWithContext = path.normalize context+'/'+inputPath

		return pathWithContext



	testConditions: (allowedConditions, conditionsString)->
		conditions = conditionsString.split(/,\s?/).filter (nonEmpty)-> nonEmpty

		for condition in conditions
			return false if not allowedConditions.includes(condition)

		return true



module.exports = helpers