REGEX = require '../constants/regex'

module.exports = prepareMultilineReplacement = (sourceContent, targetContent, lines, range)->
	if targetContent.lines().length <= 1
		return targetContent
	else
		loc = lines.locationForIndex(range[0])
		contentLine = sourceContent.slice(range[0] - loc.column, range[1])
		priorWhitespace = contentLine.match(REGEX.initialWhitespace)?[0] or ''
		hasPriorLetters = contentLine.length - priorWhitespace.length > range[1]-range[0]

		if not priorWhitespace
			return targetContent
		else
			targetContent
				.split '\n'
				.map (line, index)-> if index is 0 and hasPriorLetters then line else "#{priorWhitespace}#{line}"
				.join '\n'

