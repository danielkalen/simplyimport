module.exports = accumulateRangeOffsetBelow = (pos, ranges, offset, {rangeOffset=0})->
	for range in ranges
		sourceSTART = pos.start+offset
		sourceEND = pos.end+offset

		rangeSTART = range.start+rangeOffset
		rangeEND = range.end+rangeOffset
		rangeEND -= range.diff
		
		break if rangeSTART > sourceSTART and rangeEND > sourceSTART # source is before this range
		break if rangeSTART <= sourceSTART and sourceEND <= rangeEND # source is inside this range (e.g. import inside inline import)
		offset += range.diff

	return offset