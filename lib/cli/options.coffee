module.exports =
	'i':
		alias: 'input'
		describe: 'Path of the file to compile (stdin will be used if omitted)'
		type: 'string'

	'o':
		alias: 'output'
		describe: 'Path of file/dir to write the compiled file to (stdout will be used if omitted)'
		type: 'string'

	'c':
		alias: 'conditions'
		describe: 'Conditions list that import statements which have conditions should match against. \'*\' will match all conditions. Syntax: -c condA [condB...]'
		type: 'array'

	'r':
		alias: 'recursive'
		describe: 'Follow/attend import statements inside imported files, (--no-r to disable) (default:true)'
		default: undefined
		type: 'boolean'

	'p':
		alias: 'preserve'
		describe: 'Invalid import statements should be kept in the file in a comment format (default:false)'
		default: undefined
		type: 'boolean'

	't':
		alias: 'transform'
		describe: 'Path or module name of the browserify-style transform to apply to the bundled file'
		default: undefined
		type: 'string'

	'g':
		alias: 'globalTransform'
		describe: 'Path or module name of the browserify-style transform to apply each imported file'
		default: undefined
		type: 'string'

	'C':
		alias: 'compile-coffee-children'
		describe: 'If a JS file is importing coffeescript files, the imported files will be compiled to JS first (default:false)'
		default: undefined
		type: 'boolean'

	'include-path-comments':
		describe: 'Include a full path ref before each module definition as comments (for debugging) (default:false)'
		default: undefined
		type: 'boolean'




