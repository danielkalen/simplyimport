lineCount = (string)->
	string.match(/\n/g)?.length or 0

module.exports = lineCount.memoize()