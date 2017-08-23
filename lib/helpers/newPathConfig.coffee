helpers = require './'
extend = require 'extend'
chalk = require 'chalk'
Path = require './path'

template = (existing)-> extend
	pathAbs: ''
	path: ''
	pathDebug: ''
	pathRel: ''
	pathBase: ''
	pathExt: ''
	pathName: ''
	context: ''
	contextRel: ''
	suppliedPath: ''
, existing

module.exports = (pathAbs, entryContext, config)->
	entryContext ?= process.cwd()
	o = output = template(config)
	o.pathAbs = pathAbs
	o.context = helpers.getNormalizedDirname(pathAbs)
	o.contextRel = Path.relative(entryContext, o.context)
	o.path = helpers.simplifyPath(pathAbs)
	o.pathDebug = chalk.dim(o.path)
	o.pathRel = Path.relative(entryContext, pathAbs)
	o.pathExt = Path.extname(pathAbs).toLowerCase().slice(1)
	o.pathExt = 'yml' if o.pathExt is 'yaml'
	o.pathBase = Path.basename(pathAbs)
	o.pathName = Path.basename pathAbs, Path.extname(pathAbs)
	return output