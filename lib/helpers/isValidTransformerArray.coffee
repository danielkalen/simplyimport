

module.exports = isValidTransformerArray = (transformer)->
	Array.isArray(transformer) and
	transformer.length is 2 and
	typeof transformer[0] is 'string' and
	typeof transformer[1] is 'object' and
	transformer[1] not instanceof Array
