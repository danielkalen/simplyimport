Promise = require 'bluebird'
promiseBreak = require 'promise-break'
program = require 'commander'
chalk = require 'chalk'
fs = require 'fs'

collectArgs = (arg, store)-> store.push(arg); return store
handleError = (err)->
	console.error(err)
	process.exit(1)

exports = module.exports = []
exports.push
	command: ["bundle [path]"]
	description: "create a bundle for the specified file (if no path given the stdin will be used)"
	options: [
		["-d, --debug", "enable source maps"]
		["-o, --output", "path to write the bundled file to; will be written to stdout by default"]
		["-i, --ignore-file <file>", "replace the specified file with an empty stub; can be a glob", collectArgs, []]
		["-e, --exclude-file <file>", "avoid bundling the specified file (import statement will be left as is); can be a glob", collectArgs, []]
		["-t, --transform <transformer>", "apply a transformer to all files in the entry file's package scope (use multiple times for multiple transforms)", collectArgs, []]
		["-g, --global-transform <transformer>", "apply a transformer to all files encountered (including node_modules/ ones)", collectArgs, []]
		["-f, --final-transform <transformer>", "apply a transformer to the final bundled file", collectArgs, []]
		["-u, --umd <bundleName>", "build the bundle as a UMD bundle under the specified name"]
		["--target <node|browser>", "the target env this bundle will be run in; when 'node' files encountered in node_modules/ won't be included (default:#{chalk.dim 'browser'})"]
		["--return-loader", "return the loader function instead of loading the entry file on run time"]
		["--return-exports", "export the result of the entry file under module.exports (useful for node env)"]
		["--loader-name <name>", "the variable name to use for the bundle loader (default:#{chalk.dim 'require'})"]
		["--ignore-transform <transformer>", "avoid applying the specified transform regardless of where it was specified"]
		["--no-dedupe", "turn off module de-duplication (i.e. modules with the same hash)"]
		["--no-pkg-config", "turn off package.json config resolution for entry file (i.e. config defined in package will be ignored)"]
		["--use-paths", "use imports' paths instead of assigned numeric IDs in require statements"]
		["--ignore-globals", "skip automatic scan & insertion of process, global, Buffer, __filename, __dirname"]
		["--ignore-missing", "ignore imports referencing unpresent files (will be replaced with an empty stub)"]
		["--ignore-syntax-errors", "ignore syntax errors in imported files"]
		["--ignore-errors", "avoid halting the bundling process due to encountered errors"]
		["--match-all", "match all conditionals encountered across files"]
		["--env <envFile>", "load the provided env file to be used for conditionals and envify transform"]
	]

	action: (file, options)->
		program.specified = true

		Promise.resolve()
			.then ()->
				if options.file=file
					promiseBreak()
				else
					setTimeout (()-> program.help() if not options.src?), 250
					require('get-stream')(process.stdin)
			
			.then (content)-> options.src = content
			.catch promiseBreak.end
			.then ()-> require('../').bundle(options)
			.then (compiled)->
				if options.output
					fs.writeAsync(options.output, compiled)
				else
					process.stdout.write(compiled)
			
			.catch handleError

exports.push
	command: ["list [path]"]
	description: "list the import tree for the file located at the specified path (if no path given the stdin will be used)"
	options: [
		["-t, --time", "include compile time for each file"]
		["-s, --size", "include content size of each file"]
		["-g, --gzip", "use gzip size when --size flag is on"]
		["-d, --depth [number]", "maximum level of imports to scan through (default:#{chalk.dim '0'})"]
		["-e, --exclude [path]", "file to exclude", collectArgs, []]
		["-c, --conditionals", "consider conditionals"]
		["--expand-modules", "list all imports of external modules"]
		["--show-errors", "halt the list task upon error and log it to the console"]
		["--target <node|browser>", "the target env this bundle will be run in"]
		["--env <envFile>", "load the provided env file to be used for conditionals and envify transform"]
		["--precision <number>", "precision of the file sizes number (default:#{chalk.dim '0'})"]
	]
	action: (file, options)->
		program.specified = true
		options.flat = false
		options.precision = Number(options.precision) or 0
		options.content = true if options.size
		options.ignoreErrors = false if options.showErrors
		options.matchAllConditions = false if options.conditionals
		fileTree = null

		Promise.resolve()
			.then ()->
				if options.file=file
					promiseBreak()
				else
					setTimeout (()-> program.help() if not options.src?), 250
					require('get-stream')(process.stdin)
			
			.then (content)-> options.src = content
			.catch promiseBreak.end
			.then ()-> require('../').scan(options)
			.then (tree)-> fileTree = new (require './fileTree')(options, tree)
			.then ()-> fileTree.compute()
			.then ()-> fileTree.render()
			.catch handleError





