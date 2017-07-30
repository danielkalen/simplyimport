findPkgJson = require 'read-pkg-up'
helpers = require './'

module.exports = resolveEntryPackage = (task)->
	### istanbul ignore next ###
	Promise.resolve()
		.then ()-> findPkgJson(normalize:false, cwd:task.options.context).then(helpers.normalizePackage)
		.then (pkg)->
			task.options.pkg = pkg
			
			unless task.options.src or task.options.target is 'node'
				if typeof pkg.browser is 'object' and pkg.browser[task.entryInput]
					task.entryInput = pkg.browser[task.entryInput]

			return pkg

		.catch ()->
			return task.options.pkg = {dirPath:process.cwd(), srcPath:"#{process.cwd()}/package.json", main:'index.js'}