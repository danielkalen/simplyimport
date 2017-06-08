through = require 'through2'

module.exports = (file)->	
	chunks = []
	through(
		(chunk, enc, done)->
			chunks.push(chunk); done()
		
		(done)->
			replaced = Buffer.concat(chunks).toString().replace /gHi/g, 'GhI'
			@push(replaced)
			done()
	)