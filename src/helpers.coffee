fs = require 'fs'
path = require 'path'
regEx = require './regex'

helpers = 
	getFileContents: (inputPath, isCoffeeFile)->
		extension = if isCoffeeFile then '.coffee' else '.js'
		inputPathHasExt = regEx.fileExt.test(inputPath)
		inputPath = inputPath+extension if !inputPathHasExt
		
		if @checkIfInputExists(inputPath)
			return fs.readFileSync(inputPath).toString()
		else return false



	getNormalizedDirname: (inputPath)->
		path.normalize( path.dirname( path.resolve(inputPath) ) )



	checkIfInputExists: (inputPath)->
		try
			return fs.statSync(inputPath).isFile()
		catch error
			return false


	checkIfIsCoffee: (inputPath)->
		inputPath.match(regEx.fileExt)?[1].toLowerCase() is 'coffee'



module.exports = helpers