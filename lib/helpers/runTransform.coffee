Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require './'
streamify = require 'streamify-string'
getStream = require 'get-stream'
stringHash = require 'string-hash'



runTransform = (file, content, transformer, transformOpts)->
	Promise.resolve()
		.then ()-> transformer.fn(file.pathAbs, transformOpts, file, content)
		.tap (result)->
			switch
				when helpers.isStream(result) then result
				when typeof result is 'string' then promiseBreak(result)
				when typeof result is 'function' then promiseBreak(result(content))
				else throw new Error "invalid result of type '#{typeof result}' received from transformer"

		.then (transformStream)-> getStream streamify(content).pipe(transformStream)
		.catch promiseBreak.end


module.exports = runTransform.memoize (file, content, transformer, flags)->
	stringHash """
		#{file.pathAbs}
		#{flags._flags.debug}
		#{content}
		#{transformer.name}
		#{transformer.fn.toString()}
	"""

