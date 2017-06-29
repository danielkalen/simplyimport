EXTENSIONS = require '../constants/extensions'
helpers = require('./')

module.exports = isMixedExtStatement = (statement)->
	source = statement.source.pathExt
	target = statement.target.pathExt
	sourceRelated = helpers.relatedExtensions(source)
	targetRelated = helpers.relatedExtensions(target)

	return  source isnt target and
			(
				sourceRelated isnt targetRelated or
				target is 'js' and # and source is a transpiled type importing a js file (e.g. coffeescript, typescript)
				source isnt 'bin' # but we would consider bin files as js files
			) and
			targetRelated isnt EXTENSIONS.data