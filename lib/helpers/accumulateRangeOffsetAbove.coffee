module.exports = accumulateRangeOffsetAbove = (pos, ranges)->
	offset = 0
	for range in ranges
		break if range[0] > pos[0] and range[0] > pos[1]
		offset += range[2]

	return offset