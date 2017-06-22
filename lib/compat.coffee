Promise = require 'bluebird'
through = require 'through2'
promiseBreak = require 'promise-break'

transform = (file, opts)->
	flags = opts?._flags or {}
	chunks = []
	through(
		(chunk, enc, done)->
			chunks.push(chunk); done()
		
		(done)->
			Promise.resolve()
				.then ()-> compile(file, Buffer.concat(chunks).toString(), flags)
				# .then (compiled)-> console.log(compiled) or process.exit()
				.then (compiled)=> @push(compiled)
				.then ()-> done()
				.catch done
	)


compile = (file, src, flags)->
	# console.log file, flags
	result=require('./').compile {
		file, src
		debug: flags.debug
		bundleExternal: false
		usePaths: flags.fullPaths
		ignoreMissing: flags.ignoreMissing
		ignoreTransform: flags.ignoreTransform
		loaderName: '_s$m'
	}










module.exports = transform