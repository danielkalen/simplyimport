module.exports = accumulateRangeOffsetAbove = (pos, ranges)->
	offset = 0
	for range in ranges
		continue if range[0] < pos[0]+offset and range[0] < pos[1]+offset
		offset += range[2]

	return offset