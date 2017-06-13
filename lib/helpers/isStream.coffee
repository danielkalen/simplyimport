
module.exports = (object)->
	object? and
	typeof object is 'object' and
	typeof object.pipe is 'function'