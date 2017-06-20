module.exports = accumulateRangeOffsetBelow = (pos, ranges, offset, rangeOffset=0)->
	for range in ranges
		sourceSTART = if offset > 0 then pos[0]+offset else pos[0]
		sourceEND = if offset > 0 then pos[1]+offset else pos[1]
		rangeSTART = range[0]+rangeOffset
		rangeEND = range[1]+rangeOffset
		
		break if rangeSTART > sourceSTART and rangeEND > sourceSTART
		offset += range[2]

	return offset