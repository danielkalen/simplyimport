extend = require 'extend'
helpers = require './helpers'
Path = require './helpers/path'
{EMPTY_STUB} = require('./constants')

class Package
	main: 'index.js'
	simplyimport: specific: {}
	
	constructor: (data, path)->
		extend(@, data) if data
		@srcPath = path
		@dirPath = Path.dirname(path)
		@main = Path.resolve(@dirPath, @main)
	
		if @browser then switch typeof @browser
			when 'string'
				@browser = Path.resolve(@dirPath, @browser) if helpers.isLocalModule(@browser)
				@browser = "#{@main}":@browser

			when 'object'
				browserField = @browser
				
				for key,value of @browser
					if typeof value is 'string' and helpers.isLocalModule(value)
						@browser[key] = value = Path.resolve(@dirPath, value)

					else if value is false
						@browser[key] = EMPTY_STUB

					if helpers.isLocalModule(key)
						newKey = Path.resolve(@dirPath, key)
						@browser[newKey] = value
						delete @browser[key]

	# extendTaskOptions: (target)->
	# 	a



Package.create = (data, path)->
	new Package(data, path)


module.exports = Package