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


	getDirListing: (dirPath)->
		if dirListingCache[dirPath]?
			return dirListingCache[dirPath]
		else
			return dirListingCache[dirPath] = fs.readdirSync(dirPath)


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
			.replace regEx.comment.multiLine, '$1'
			.replace regEx.escapedNewLine, ''
			.replace regEx.fileContent, (entire, spacing, content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
				"#{spacing}`#{helpers.escapeBackticks(content)}`"



	normalizeFilePath: (inputPath, context)->
		inputPath = inputPath
			.replace /['"]/g, '' # Remove quotes form pathname
			.replace /\s+$/, '' # Remove whitespace from the end of the string

		resolvedPath = path.normalize(context+'/'+inputPath)

		if not path.extname(resolvedPath)
			inputFileName = path.basename(resolvedPath)
			parentDir = path.dirname(resolvedPath)
			parentDirListing = @getDirListing(parentDir)
			inputPathMatches = parentDirListing.filter (targetPath)-> targetPath.includes(inputFileName)

			if inputPathMatches.length
				fileMatch = inputPathMatches.find (targetPath)-> targetPath.replace(inputFileName, '').split('.').length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname
				exactMatch = inputPathMatches.find (targetPath)-> targetPath is inputFileName

				if fileMatch
					resolvedPath = "#{parentDir}/#{fileMatch}"
				else #if exactMatch
					resolvedPath = "#{parentDir}/#{inputFileName}"
					pathStats = fs.statSync(resolvedPath)

					if pathStats.isDirectory()
						targetDirListing = @getDirListing(resolvedPath)
						indexFile = targetDirListing.find (file)-> file.includes('index')

						if indexFile
							resolvedPath = "#{parentDir}/#{inputFileName}/#{indexFile}"
						else
							resolvedPath = "#{parentDir}/#{inputFileName}/index.js"

		return resolvedPath


dirListingCache = {}
module.exports = helpers