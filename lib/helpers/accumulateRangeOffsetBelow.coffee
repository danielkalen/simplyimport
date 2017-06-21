module.exports = accumulateRangeOffsetBelow = (pos, ranges, offset, rangeOffset=0, noNegative)->
	for range in ranges
		if offset < 0 and noNegative
			sourceSTART = pos[0]
			sourceEND = pos[1]
		else
			sourceSTART = pos[0]+offset
			sourceEND = pos[1]+offset

		rangeSTART = range[0]+rangeOffset
		rangeEND = range[1]+rangeOffset
		
		break if rangeSTART > sourceSTART and rangeEND > sourceSTART
		offset += range[2]

	return offset