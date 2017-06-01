helpers = require('./')

module.exports = resolveTransformer = (transformer, basedir)-> Promise.resolve().then ()-> switch
	when typeof transformer is 'function'
		{'fn':transformer, 'opts':{}}

	when typeof transformer is 'object' and helpers.isValidTransformerArray(transformer)
		{'fn':helpers.safeRequire(transformer[0], basedir), 'opts':transformer[1], 'name':transformer[0]}

	when typeof transformer is 'string'
		{'fn':helpers.safeRequire(transformer, basedir), 'opts':{}, 'name':transformer}

	else throw new Error "Invalid transformer provided (must be a function or a string representing the file/module path of the transform function). Received:'#{String(transformer)}'"
