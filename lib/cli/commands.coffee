Promise = require 'bluebird'
promiseBreak = require 'promise-break'
program = require 'commander'
chalk = require 'chalk'
fs = require 'fs'
dim = chalk.dim

exports = module.exports = []
exports.push
	command: ["bundle #{dim '[path]'}", "bundle the specified path (if no path given the stdin will be used)", isDefault:true]
	options: [
		["-d, --debug", "enable source maps"]
		["-o, --output", "path to write the bundled file to; will be written to stdout by default"]
		["-i, --ignore-file #{dim '<file>'}", "replace the specified file with an empty stub; can be a glob"]
		["-e, --exclude-file #{dim '<file>'}", "avoid bundling the specified file (import statement will be left as is); can be a glob"]
		["-t, --transform #{dim '<transformer>'}", "apply a transformer to all files in the entry file's package scope (use multiple times for multiple transforms)"]
		["-g, --global-transform #{dim '<transformer>'}", "apply a transformer to all files encountered (including node_modules/ ones)"]
		["-u, --umd #{dim '<bundleName>'}", "build the bundle as a UMD bundle under the specified name"]
		["--return-loader", "return the loader function instead of loading the entry file on run time"]
		["--return-exports", "export the result of the entry file under module.exports (useful for node env)"]
		["--target #{dim '<node|browser>'}", "the target env this bundle will be run in; when 'node' files encountered in node_modules/ won't be included (default:#{dim 'browser'})"]
		["--loader-name #{dim '<name>'}", "the variable name to use for the bundle loader (default:#{dim 'require'})"]
		["--ignore-transform #{dim '<transformer>'}", "avoid applying the specified transform regardless of where it was specified"]
		["--no-dedupe", "turn off module de-duplication (i.e. modules with the same hash)"]
		["--use-paths", "use imports' paths instead of assigned numeric IDs in require statements"]
		["--ignore-globals", "skip automatic scan & insertion of process, global, Buffer, __filename, __dirname"]
		["--ignore-missing", "ignore imports referencing unpresent files (will be replaced with an empty stub)"]
		["--ignore-syntax-errors", "ignore syntax errors in imported files"]
		["--ignore-errors", "avoid halting the bundling process due to encountered errors"]
		["--match-all", "match all conditionals encountered across files"]
	]
	action: (file, options)->
		program.specified = true

		Promise.resolve()
			.then ()->
				if options.file=file
					promiseBreak()
				else
					setTimeout (()-> program.help() if not options.content?), 250
					require('get-stream')(process.stdin)
			
			.then (content)-> options.src = content
			.catch promiseBreak.end
			.then ()-> require('../').compile(options)
			.then (compiled)->
				if options.output
					fs.writeAsync(options.output, compiled)
				else
					process.stdout.write(compiled)

exports.push
	command: ["list #{dim '[path]'}", "list the import tree for the bundle under the specified path (if no path given the stdin will be used)"]
	options: [
		['-s, --size', 'include gzipped size of each file']
	]
	action: (file)->
		console.log file


