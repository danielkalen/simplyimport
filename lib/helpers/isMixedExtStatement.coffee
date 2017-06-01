helpers = require('./')

module.exports = isMixedExtStatement = (statement)->
	source = statement.source.pathExt
	target = statement.target.pathExt
	sourceRelated = helpers.relatedExtensions(source)
	targetRelated = helpers.relatedExtensions(target)
	return  source isnt target and
			(
				sourceRelated isnt targetRelated or
				target is 'js' # and source is a transpiled type (e.g. coffeescript, typescript)
			) and
			sourceRelated isnt EXTENSIONS.data