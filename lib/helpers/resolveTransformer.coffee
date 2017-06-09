Promise = require 'bluebird'
helpers = require('./')
template = (fn, name='', opts={})->
	name:name
	fn:fn
	opts:opts

module.exports = resolveTransformer = (transformer, basedir)-> Promise.resolve().then ()-> switch
	when typeof transformer is 'function'
		template(transformer, transformer.name)

	when typeof transformer is 'object' and helpers.isValidTransformerArray(transformer)
		helpers.safeRequire(transformer[0], basedir).then (transformPath)->
			template(transformPath, transformer[0], transformer[1])

	when typeof transformer is 'string'
		helpers.safeRequire(transformer, basedir).then (transformPath)->
			template(transformPath, transformer)

	else throw new Error "Invalid transformer provided (must be a function or a string representing the file/module path of the transform function). Received:'#{String(transformer)}'"
