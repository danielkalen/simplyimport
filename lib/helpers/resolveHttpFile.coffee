Path = require 'path'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
fs = require 'fs-jetpack'
axios = require 'axios'
cahlk = require 'chalk'
debug = require('debug')('simplyimport:http')


module.exports = (url)->
	ext = Path.extname(url).slice(1) or 'js'
	hash = Date.now().toString(16)
	cachedPath = Path.resolve(helpers.temp(),hash,ext)
	
	Promise.resolve()
		.tap ()-> debug "resolving via HTTP #{chalk.dim url}"
		.then ()-> axios.head(url).get('headers')
		.then (headers)->
			if not headers.etag
				promiseBreak(false)
			else
				hash = headers.etag
				promiseBreak(false) if not fs.exists(cachedPath = Path.resolve(helpers.temp(),hash,ext))
		
		.tap ()-> debug "using cached version of #{chalk.dim url}"
		.then ()-> fs.readFileAsync(cachedPath)
		.catch promiseBreak.end
		.then (content)-> promiseBreak(content) if typeof content is 'string'
		
		.tap ()-> debug "downloading #{chalk.dim url}"
		.then ()-> axios.get(url).get('data')
		.tap ()-> debug "finished download #{chalk.dim url}"
		
		.catch promiseBreak.end
		.then (result)-> fs.writeAsync cachedPath, result
		.then ()-> return cachedPath
		
		.catch (err)->
			if err.response
				err = new Error "failed to download #{url} (#{err.response.status})"
				err.response = err.response?.data
				err.headers = err.response?.headers

			throw err

