Path = require 'path'
findPkgJson = require 'read-pkg-up'
Promise = require 'bluebird'
helpers = require('./')
{EMPTY_FILE, EMPTY_FILE_END} = require('../constants')
coreModuleShims = require('../constants/coreShims')
extensions = require('../constants/extensions').all.map (ext)-> ".#{ext}"
resolvers =
	node: Promise.promisify require('resolve')
	browser: Promise.promisify require('browser-resolve')

module.exports = resolveModulePath = (moduleName, importer, target='browser')-> Promise.resolve().then ()->
	resolver = resolvers[target]
	# shims = importer.task?.shims or coreModuleShims
	shims = coreModuleShims
	output =
		'file': Path.resolve(importer.context, moduleName)
		'pkg': importer.pkgFile

	switch
		when helpers.isLocalModule(moduleName) and moduleName[moduleName.length-1] isnt '/'
			resolveLocalModule {output, moduleName, importer, target}
		
		when helpers.isHttpModule(moduleName)
			helpers.resolveHttpModule(moduleName).then (result)->
				resolveModulePath(result, importer, target)

		else
			moduleName = output.file = shims[moduleName] if hasShim=shims[moduleName]
			resolver(moduleName, {basedir:importer.context, filename:importer.pathAbs, modules:shims, extensions})
				.then (moduleFullPath)->
					unless coreModuleShims[moduleFullPath] or helpers.isLocalModule(moduleFullPath)
						return resolveModulePath(moduleFullPath, importer, target)

					findPkgJson(normalize:false, cwd:moduleFullPath).then (result)->
						output.file = moduleFullPath
						output.pkg = result.pkg
						
						if moduleFullPath.endsWith EMPTY_FILE_END
							output.isEmpty = true
							delete output.pkg
						else
							helpers.resolvePackagePaths(result.pkg, result.path)
						
						return output

				.catch(
					(err)-> err.message.startsWith('Cannot find module')
					()->
						if helpers.isLocalModule(moduleName)
							return output
						else
							helpers.resolveModulePath("./#{moduleName}", importer, target)
				)


resolveLocalModule = ({output, moduleName, importer, target})->
	pkg = importer.pkgFile
	
	if pkg and typeof pkg.browser is 'object' and target isnt 'node'
		replacedPath = helpers.resolveBrowserFieldPath(pkg, moduleName, importer.context)

		if replacedPath?
			if typeof replacedPath isnt 'string'
				output.file = EMPTY_FILE
				output.isEmpty = true
			else
				output.file = replacedPath

	# output.pkg = pkg
	return output