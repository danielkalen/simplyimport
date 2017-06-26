REGEX = require '../constants/regex'

module.exports = prepareMultilineReplacement = (sourceContent, targetContent, lines, range)->
	if targetContent.lines().length <= 1
		return targetContent
	else
		loc = lines.locationForIndex(range.start)
		contentLine = sourceContent.slice(range.start - loc.column, range.end)
		priorWhitespace = contentLine.match(REGEX.initialWhitespace)?[0] or ''
		hasPriorLetters = contentLine.length - priorWhitespace.length > range.end-range.start

		if not priorWhitespace
			return targetContent
		else
			targetContent
				.split '\n'
				# .map (line, index)-> if index is 0 and hasPriorLetters then line else "#{priorWhitespace}#{line}"
				.map (line, index)-> if index is 0 then line else "#{priorWhitespace}#{line}"
				.join '\n'

