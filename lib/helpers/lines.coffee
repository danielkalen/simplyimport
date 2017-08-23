LinesAndColumns = require('lines-and-columns').default

lines = (content)->
	new LinesAndColumns(content)

module.exports = lines.memoize()