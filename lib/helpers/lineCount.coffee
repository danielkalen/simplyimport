

module.exports = lineCount = (string)->
	string.match(/\n/g)?.length or 0