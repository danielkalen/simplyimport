helpers = require('./')

module.exports = resolveFilePath = (input, entryContext, useDirCache)->
	Promise.resolve()
		.then ()->
			extname = Path.extname(input).slice(1).toLowerCase()
			if extname and EXTENSIONS.all.includes(extname)
				promiseBreak(input)
			else
				Path.parse(input)
		
		.then (params)->
			helpers.getDirListing(params.dir, useDirCache).then (list)-> [params, list]
		
		.then ([params, dirListing])->
			inputPathMatches = dirListing.filter (targetPath)-> targetPath.includes(params.base)

			if not inputPathMatches.length
				return promiseBreak(input)
			else
				exactMatch = inputPathMatches.find(params.base)
				fileMatch = inputPathMatches.find (targetPath)->
					fileNameSplit = targetPath.replace(params.base, '').split('.')
					return !fileNameSplit[0] and fileNameSplit.length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname

				if fileMatch
					promiseBreak Path.join(params.dir, fileMatch)
				else #if exactMatch
					return params
		
		.then (params)->
			resolvedPath = Path.join(params.dir, params.base)
			fs.inspectAsync(resolvedPath).then (stats)->
				if stats.type isnt 'dir'
					promiseBreak(resolvedPath)
				else
					return params

		.then (params)->
			helpers.getDirListing(Path.join(params.dir, params.base), useDirCache).then (list)-> [params, list]

		.then ([params, dirListing])->
			indexFile = dirListing.find (file)-> file.includes('index')
			return Path.join(params.dir, params.base, if indexFile then indexFile else 'index.js')

		.catch promiseBreak.end
		.then (pathAbs)->
			context = helpers.getNormalizedDirname(pathAbs)
			contextRel = context.replace(entryContext+'/', '')
			path = helpers.simplifyPath(pathAbs)
			pathRel = pathAbs.replace(entryContext+'/', '')
			pathExt = Path.extname(pathAbs).toLowerCase().slice(1)
			pathExt = 'yml' if pathExt is 'yaml'
			pathBase = Path.basename(pathAbs)
			suppliedPath = input
			return {pathAbs, path, pathRel, pathBase, pathExt, context, contextRel, suppliedPath}
