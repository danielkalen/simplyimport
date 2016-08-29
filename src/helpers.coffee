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
		prevContent = ''
		importLine.replace regEx.import, (importLine, priorContent, spacing)->
			prevContent = priorContent+spacing
		
		return importLine.replace prevContent, "#{prevContent}#{comment} "


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