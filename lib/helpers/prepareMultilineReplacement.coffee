REGEX = require '../constants/regex'
stringPos = require 'string-pos'

module.exports = prepareMultilineReplacement = (sourceContent, targetContent, range)->
	if targetContent.split('\n').length <= 1
		return targetContent
	else
		loc = stringPos(sourceContent, range.start)
		contentLine = sourceContent.slice(range.start - loc.column, range.end)
		priorWhitespace = contentLine.match(REGEX.initialWhitespace)?[0] or ''
		hasPriorLetters = contentLine.length - priorWhitespace.length > range.end-range.start

		if not priorWhitespace
			return targetContent
		else
			targetContent
				.split '\n'
				.map (line, index)-> if index is 0 then line else "#{priorWhitespace}#{line}"
				.join '\n'

