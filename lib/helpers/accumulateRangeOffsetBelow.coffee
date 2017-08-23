module.exports = accumulateRangeOffsetBelow = (pos, ranges, offset)->
	for range in ranges
		targetSTART = pos.start+offset
		targetEND = pos.end+offset
		targetIsBetween = targetSTART < range.start and range.start < targetEND < range.end

		# tweener means 'between' i.e. between import/export collection & replacement. This will be true only for export-less modules that were modified to contain 'module.exports = '
		rangeOffset = if range.isTweener or targetIsBetween then offset else 0
		rangeSTART = range.start+rangeOffset
		rangeEND = range.end+rangeOffset
		rangeEND -= range.diff
		
		break if rangeSTART > targetSTART and rangeEND > targetSTART # source is before this range
		break if rangeSTART <= targetSTART and targetEND <= rangeEND # source is inside this range (e.g. import inside inline import)
		offset += range.diff

	return offset