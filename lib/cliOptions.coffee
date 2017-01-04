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

	'u':
		alias: 'uglify'
		describe: 'Uglify/minify the compiled file (default:false)'
		default: undefined
		type: 'boolean'

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
		alias: 'to-es5'
		describe: 'Transpile all ES6 code present in imported files to be ES5 compatible (default:false)'
		default: undefined
		type: 'boolean'

	'C':
		alias: 'compile-coffee-children'
		describe: 'If a JS file is importing coffeescript files, the imported files will be compiled to JS first (default:false)'
		default: undefined
		type: 'boolean'




