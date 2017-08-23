Promise = require 'bluebird'
Path = require '../helpers/path'
chalk = require 'chalk'
matchGlob = require '../helpers/matchGlob'
streamify = require 'streamify-string'
gzipped = Promise.promisifyAll require('gzipped')
metric = require 'sugar/number/metric'
isEqual = require 'sugar/object/isEqual'
bytes = (number, precision)->
	result = metric(number, precision)
	if Number(result)
		result = (result/1000)+'k'
	return result+'b'


class FileTree
	constructor: (@options, @tree)->
		@output = {}

	compute: ()->
		Promise.bind(@)
			.then ()-> @calcFileSizes(@tree.entry) if @options.size
			.then ()-> @calcRenderTree(@tree.entry, @output)

	render: ()->
		console.log require('treeify').asTree(@output)


	calcRenderTree: (target, output, parent)->
		return if @options.exclude.some(matchGlob.bind(null, target.file))
		[targetPath, isExternal] = @formatPath(target, parent)
		output[targetPath] = {}

		unless isExternal and not @options.expandModules
			@calcRenderTree(child, output[targetPath], target) for child in target.imports

		return output


	formatPath: (target, parent)->
		result = Path.relative(process.cwd(), target.file)
		if parent
			commondir = Path.dirname Path.relative(process.cwd(), parent.file)
			result = result.replace commondir, (p)-> chalk.dim(p)
		
		if result.startsWith('node_modules')
			isExternal = true
			result = result.replace(/^.*node_modules\//,'').replace(/^[^\/]+/, (m)-> chalk.magenta(m))

		if @options.time
			result += chalk.yellow(" #{target.time}ms")
			result += chalk.dim("/#{@aggregate target,'time'}ms") if target.imports.length
			result += '  | ' if @options.size
		
		if @options.size
			result += chalk.green(" #{bytes target.size, @options.precision}")
			result += chalk.dim("/#{bytes @aggregate(target,'size'),@options.precision}") if target.imports.length

		return [result, isExternal]


	aggregate: (target, property, transform)->
		value = target[property]
		value += @aggregate(child, property) for child in target.imports
		return value


	calcFileSizes: (target)->
		Promise.resolve(target.content).bind(@)
			.then @calcSize
			.then (size)-> target.size = if @options.gzip then size.compressed else size.original
			.return target.imports
			.map @calcFileSizes


	calcSize: ((string)->
		Promise.resolve(string)
			.then streamify
			.then gzipped.calculateAsync
	).memoize()





module.exports = FileTree