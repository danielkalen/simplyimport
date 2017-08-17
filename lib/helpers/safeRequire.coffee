Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require 'path'
fs = require 'fs-jetpack'
helpers = require './'

safeRequire = (targetPath, importer)->
	targetPath = 'envify/custom' if targetPath is 'envify'
	resolved = targetPath
	context = importer.pkg.dirPath

	Promise.resolve()
		.then ()-> helpers.resolveModulePath(targetPath, importer)
		.get 'file'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)

		.then ()-> helpers.resolveFilePath(targetPath, importer, '')
		.get 'pathAbs'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		
		.then ()-> helpers.resolveFilePath(Path.resolve(context, targetPath), importer, '').get('pathAbs')
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		.get 'pathAbs'
		
		.then ()-> helpers.resolveFilePath(Path.resolve(context, 'node_modules', targetPath), importer, '').get('pathAbs')
		.get 'pathAbs'

		.catch promiseBreak.end
		.then (resolvedPath=targetPath)->
			result = require(resolved=resolvedPath)
			if targetPath is 'envify/custom'
				return result(importer.task.options.env)
			else
				return result

		.catch (err)->
			if err.message.includes('Cannot find module') and err.message.split('\n')[0].includes(resolved)
				throw new Error "'#{targetPath}' could not be found"
			else
				throw err

module.exports = safeRequire.memoize (targetPath, importer)->
	if helpers.isLocalModule(targetPath)
		"#{importer.task.ID}/#{Path.resolve importer.pkg.dirPath, targetPath}"
	else
		"#{importer.task.ID}/#{targetPath}"
