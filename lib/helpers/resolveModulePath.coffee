Path = require 'path'
findPkgJson = require 'read-pkg-up'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
{EMPTY_STUB} = require('../constants')
extensions = require('../constants/extensions').all.map (ext)-> ".#{ext}"
resolver = Promise.promisify require('resolve')

module.exports = resolveModulePath = (moduleName, importer, target='browser')->
	isLocalModule = helpers.isLocalModule(moduleName)
	output =
		'file': Path.resolve(importer.context, moduleName)
		'pkg': importer.pkg

	Promise.resolve()
		.then ()-> switch
			when isLocalModule and not isDir(moduleName)
				return output.file
			
			when helpers.isHttpModule(moduleName)
				helpers.resolveHttpModule(moduleName).then (result)->
					promiseBreak resolveModulePath(result, importer, target)

			else
				pathFilter = (pkg, path, relativePath)->
					console.log path, relativePath
					return path
				resolver(moduleName, {basedir:importer.context, extensions, pathFilter})
		
		.then (moduleResolved)->
			Promise.props
				file: moduleResolved,
				pkg: findPkgJson(normalize:false, cwd:moduleResolved).then(helpers.normalizePackage)

		.tap (output)->
			if not output.pkg or output.pkg.srcPath is importer.pkg.srcPath
				output.pkg = importer.pkg

		.then (output)->
			resolveAllAliases(output.file, output, importer, target)
			resolveAllAliases(moduleName, output, importer, target)

			return output


		.then (output)->
			if output.file is EMPTY_STUB
				delete output.pkg
			
			return output

		.catch promiseBreak.end
		.catch(
			(err)-> err.message.startsWith('Cannot find module')
			()->
				if isLocalModule
					return output
				else
					helpers.resolveModulePath("./#{moduleName}", importer, target)
		)
		.catch promiseBreak.end


resolveAllAliases = (moduleName, output, importer, target)->
	alias = moduleName

	if output.pkg.browser
		alias = aliasFromOutput = resolveAlias(alias, importer, target, output.pkg.browser)

	if importer.pkg.browser and importer.pkg isnt output.pkg
		alias = resolveAlias(alias, importer, target, importer.pkg.browser)

	if importer.pkg isnt importer.task.entryFile.pkg
		alias = resolveAlias(alias, importer, target, importer.task.shims)

	if alias isnt output.file and alias isnt moduleName
		importer = simulateImporter(output, importer) if alias is aliasFromOutput
		promiseBreak resolveModulePath(alias, importer, target)



resolveAlias = (moduleName, importer, target, shims)->
	return moduleName if target is 'node'
	alias = helpers.resolveAlias(moduleName, importer.context, importer.pkg.dirPath, shims)

	if alias is false
		return EMPTY_STUB
	else
		return alias or moduleName


isDir = ((path)->
	path[path.length-1] is '/'
).memoize()

simulateImporter = (output, importer)->
	context: output.pkg.dirPath
	pkg: output.pkg
	task: importer.task
	simulated: true





