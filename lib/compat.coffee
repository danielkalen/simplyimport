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
				.then ()-> compile(file, Buffer.concat(chunks).toString(), flags, opts)
				.then (compiled)=> @push(compiled)
				.then ()-> done()
				.catch done
	)


compile = (file, src, flags, opts)->
	require('./').compile {
		file, src
		umd: opts.umd
		debug: flags.debug
		bundleExternal: false
		returnExports: true
		usePaths: flags.fullPaths
		ignoreMissing: flags.ignoreMissing
		ignoreTransform: flags.ignoreTransform
		loaderName: '_s$m'
	}










module.exports = transform