module.exports =
	'i':
		alias: 'input'
		describe: 'Path of the file to compile (relative or absolute)'
		type: 'string'

	'o':
		alias: 'output'
		describe: 'Path of file/dir to write the compiled file to (stdout will be used if omitted)'
		type: 'string'

	'c':
		alias: 'conditions'
		describe: 'Conditions list that import directives which have conditions should match against. Syntax: -c condA [condB...]'
		type: 'array'

	'u':
		alias: 'uglify'
		describe: 'Uglify/minify the compiled file (default:false)'
		default: undefined
		type: 'boolean'

	'r':
		alias: 'recursive'
		describe: 'Follow/attend import directives inside imported files, (--no-r to disable) (default:true)'
		default: undefined
		type: 'boolean'

	'p':
		alias: 'preserve'
		describe: 'Invalid import directives should be kept in the file in a comment format (default:false)'
		default: undefined
		type: 'boolean'

	's':
		alias: 'silent'
		describe: 'Suppress warnings (default:false)'
		default: undefined
		type: 'boolean'

	't':
		alias: 'track'
		describe: 'Prepend [commented] tracking info in the output file so that future files importing this one will know which files are already imported (default:false)'
		default: undefined
		type: 'boolean'

	'C':
		alias: 'compile-coffee-children'
		describe: 'If a JS file is importing coffeescript files, the imported files will be compiled to JS first (default:false)'
		default: undefined
		type: 'boolean'




