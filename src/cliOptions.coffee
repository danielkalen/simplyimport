module.exports =
	'i':
		alias: 'input'
		# demand: true
		describe: 'Path of the file to compile. Can be relative or absolute.'
		type: 'string'

	'o':
		alias: 'output'
		describe: 'Path of file/dir to write the compiled file to. If omitted the result will be written to stdout.'
		type: 'string'

	'c':
		alias: 'conditions'
		describe: 'Specify the conditions that @import directives with conditions should match against. Syntax: -c condA condB condC...'
		type: 'array'

	'u':
		alias: 'uglify'
		describe: 'Uglify/minify the compiled file.'
		default: undefined
		type: 'boolean'

	'r':
		alias: 'recursive'
		describe: 'Follow/attend import directives inside imported files.'
		default: undefined
		type: 'boolean'

	'p':
		alias: 'preserve'
		describe: '@import directives that have unmatched conditions should be kept in the file.'
		default: undefined
		type: 'boolean'

	's':
		alias: 'silent'
		describe: 'Suppress warnings'
		default: undefined
		type: 'boolean'