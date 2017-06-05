Promise = require 'bluebird'
original = 'stdout':process.stdout.write, 'stderr':process.stderr.write
buffer = ''
currentTarget = 'stderr'

start = (target='stderr', writeOriginal)->
	currentTarget = target
	
	process[target].write = (string)->
		buffer += string
		if writeOriginal
			original[target].apply(process, arguments)

stop = ()->
	process[currentTarget].write = original[currentTarget]
	result = buffer
	buffer = ''
	return result




module.exports.start = start
module.exports.stop = stop