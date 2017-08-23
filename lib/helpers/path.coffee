Path = require 'path'

module.exports =
	resolve: Path.resolve.memoize()
	normalize: Path.normalize.memoize()
	isAbsolute: Path.isAbsolute.memoize()
	join: Path.join.memoize()
	relative: Path.relative.memoize()
	dirname: Path.dirname.memoize()
	basename: Path.basename.memoize()
	extname: Path.extname.memoize()
	format: Path.format.memoize()
	parse: Path.parse.memoize()
	sep: Path.sep
	delimiter: Path.delimiter
	win32: Path.win32
	_makeLong: Path._makeLong.memoize()


