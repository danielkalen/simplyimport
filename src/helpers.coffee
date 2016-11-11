fs = require 'fs'
path = require 'path'
regEx = require './regex'

helpers = 
	getNormalizedDirname: (inputPath)->
		path.normalize( path.dirname( path.resolve(inputPath) ) )

	simplifyPath: (inputPath)->
		inputPath.replace process.cwd()+'/', ''

	testForComments: (line, file)->
		hasSingleLineComment = if file.isCoffee then line.includes('#') else line.includes('//')
		hasDocBlockComment = line.includes('* ')

		return hasSingleLineComment or hasDocBlockComment


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




	escapeBackticks: (content)->
		content
			.replace regEx.preEscapedBackTicks, '`'
			.replace regEx.backTicks, '\\`'



	formatJsContentForCoffee: (jsContent)->
		jsContent
			.replace regEx.comment, '$1'
			.replace regEx.escapedNewLine, ''
			.replace regEx.fileContent, (entire, spacing, content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
				"#{spacing}`#{helpers.escapeBackticks(content)}`"



module.exports = helpers