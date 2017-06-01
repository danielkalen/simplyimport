

module.exports = accumulateRangeOffset = (pos, ranges)->
	offset = 0
	for range in ranges
		continue if range[0] > pos
		offset += range[2]

	return offset