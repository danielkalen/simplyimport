Path = require 'path'
chalk = require 'chalk'
matchGlob = require '../helpers/matchGlob'


class FileTree
	constructor: (@options, @tree)->
		entry = @options.file or 'ENTRY'
		@output = {"#{entry}":{}}
		@compute(@tree, @output[entry], entry)
	

	formatPath: (target, parent)->
		result = Path.relative(process.cwd(), target.file)
		if parent
			commondir = Path.dirname Path.relative(process.cwd(), parent)
			result = result.replace commondir, (p)-> chalk.dim(p)
		
		if result.startsWith('node_modules')
			isExternal = true
			result = result.replace(/^.*node_modules\//,'').replace(/^[^\/]+/, (m)-> chalk.magenta(m))

		if @options.time
			result += chalk.yellow(" #{target.time}ms")
			result += chalk.dim("/#{@aggregate target,'time'}ms") if target.imports.length
		
		return [result, isExternal]


	aggregate: (target, property)->
		base = target[property]
		base += @aggregate(child, property) for child in target.imports
		return base



	compute: (imports, output, parent)->
		for child in imports
			[childPath, isExternal] = @formatPath(child, parent)
			
			switch
				when @options.exclude.some(matchGlob.bind(null, childPath))
					continue
				when isExternal and not @options.expandModules
					childImports = null
				when child.imports.length is 0
					childImports = null
				else
					@compute(child.imports, childImports={}, child.file)

			output[childPath] = childImports
		
		return output


	render: ()->
		console.log require('treeify').asTree(@output)








module.exports = FileTree