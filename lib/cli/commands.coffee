Promise = require 'bluebird'
Path = require 'path'
promiseBreak = require 'promise-break'
program = require 'commander'
chalk = require 'chalk'
fs = require 'fs'
matchGlob = require '../helpers/matchGlob'

collectArgs = (arg, store)-> store.push(arg); return store


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
			.then ()-> require('../').compile(options)
			.then (compiled)->
				if options.output
					fs.writeAsync(options.output, compiled)
				else
					process.stdout.write(compiled)

exports.push
	command: ["list [path]"]
	description: "list the import tree for the file located at the specified path (if no path given the stdin will be used)"
	options: [
		["-s, --size", "include gzipped size of each file"]
		["-t, --time", "include compile time for each file"]
		["-d, --depth [number]", "maximum level of imports to scan through (default:#{chalk.dim '0'})"]
		["-e, --exclude [path]", "file to exclude", collectArgs, []]
		["-c, --conditionals", "consider conditionals"]
		["--expand-modules", "list all imports of external modules"]
		["--show-errors", "halt the list task upon error and log it to the console"]
		["--target <node|browser>", "the target env this bundle will be run in"]
		["--env <envFile>", "load the provided env file to be used for conditionals and envify transform"]
	]
	action: (file, options)->
		program.specified = true
		options.flat = false
		options.ignoreErrors = false if options.showErrors
		options.matchAllConditions = false if options.conditionals

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
			.then (tree)->
				entry = options.file or 'ENTRY'
				output = {"#{entry}":{}}

				formatPath = (filePath, parent, time)->
					result = Path.relative(process.cwd(), filePath)
					if parent
						commondir = Path.dirname Path.relative(process.cwd(), parent)
						result = result.replace commondir, (p)-> chalk.dim(p)
					
					if result.startsWith('node_modules')
						isExternal = true
						result = result.replace(/^.*node_modules\//,'').replace(/^[^\/]+/, (m)-> chalk.magenta(m))

					result += chalk.yellow(" #{time}ms") if options.time
					return [result, isExternal]
				
				walk = (imports, output, parent)->
					for child in imports
						[childPath, isExternal] = formatPath(child.file, parent, child.time)
						
						switch
							when options.exclude.some(matchGlob.bind(null, childPath))
								continue
							when isExternal and not options.expandModules
								childImports = null
							when child.imports.length is 0
								childImports = null
							else
								walk(child.imports, childImports={}, child.file)

						output[childPath] = childImports
					
					return output


				walk(tree, output[entry], entry)
				console.log require('treeify').asTree(output)





