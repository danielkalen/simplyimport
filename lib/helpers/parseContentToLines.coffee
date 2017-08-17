LinesAndColumns = require('lines-and-columns').default

parseContentToLines = (content)->
	new LinesAndColumns(content)

module.exports = parseContentToLines.memoize()