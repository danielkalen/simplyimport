module.exports = (range, replacement)->
	start: range.start
	end: newEnd = range.start + replacement.length
	diff: newEnd - range.end