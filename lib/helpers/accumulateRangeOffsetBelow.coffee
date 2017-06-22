module.exports = accumulateRangeOffsetBelow = (pos, ranges, offset, {rangeOffset=0, isDeoffset=false, considerDiff=false, breakOnInnerRange=true})->
	for range in ranges
		if offset < 0 and isDeoffset
			sourceSTART = pos[0]
			sourceEND = pos[1]
		else
			sourceSTART = pos[0]+offset
			sourceEND = pos[1]+offset

		rangeSTART = range[0]+rangeOffset
		rangeEND = range[1]+rangeOffset
		rangeEND -= range[2] if considerDiff
		
		break if rangeSTART > sourceSTART and rangeEND > sourceSTART # source is before this range
		break if rangeSTART <= sourceSTART and sourceEND <= rangeEND and breakOnInnerRange # source is inside this range (e.g. import inside inline import)
		offset += range[2]

	return offset