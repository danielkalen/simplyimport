Path = require 'path'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
fs = require 'fs-jetpack'
getStream = require 'get-stream'
axios = require 'axios'
chalk = require 'chalk'
debug = require('debug')('simplyimport:http')


module.exports = (url)->
	ext = Path.extname(url.replace(/\?.+$/,'')).slice(1) or 'js'
	ext = 'tgz' if ext is 'gz'
	hash = Date.now().toString(16)
	cachedPath = Path.resolve(helpers.temp(),hash+".#{ext}")
	
	Promise.resolve()
		.tap ()-> debug "resolving via HTTP #{chalk.dim url}"
		.then ()-> axios.head(url).get('headers')
		.then (headers)->
			if not headers.etag
				promiseBreak('requires download')
			else
				hash = headers.etag.removeAll('"')
				promiseBreak('requires download') if not fs.exists(cachedPath = Path.resolve(helpers.temp(),hash+".#{ext}"))
		
		.tap ()-> debug "using cached version of #{chalk.dim url}"
		.then ()-> if ext is 'tgz'
			cachedPath = Path.resolve(helpers.temp(),hash)
		
		.catch promiseBreak.end
		.then (status)-> promiseBreak(status) unless status is 'requires download'
		
		.tap ()-> debug "downloading #{chalk.dim url}"
		.then ()-> axios.get(url, responseType:'stream').get('data')
		.then (stream)-> getStream(stream, encoding:'buffer')
		.tap ()-> debug "finished download #{chalk.dim url}"
		
		# .tap (result)-> console.log result.length, typeof result
		.then (result)-> fs.writeAsync cachedPath, result
		# .tap (result)-> console.log fs.read(cachedPath, 'buffer').length, typeof fs.read(cachedPath, 'buffer')
		.then ()-> if ext is 'tgz'
			debug "extracting tarball #{chalk.dim cachedPath}"
			gzipped = cachedPath
			cachedPath = Path.resolve(helpers.temp(),hash)+'/'
			unless fs.exists(cachedPath)
				require('tar.gz')(null,strip:1).extract(gzipped, cachedPath)

		.catch promiseBreak.end
		.then ()-> cachedPath

		.catch (err)->
			if err.response
				err = new Error "failed to download #{url} (#{err.response.status})"
				err.response = err.response?.data
				err.headers = err.response?.headers

			throw err

