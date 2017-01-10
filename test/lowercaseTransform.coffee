through = require 'through2'

module.exports = (file)->	
	through (chunk, enc, done)->
		@push chunk.toString().toLowerCase()
		done()

