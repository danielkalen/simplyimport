regEx = 
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(js|coffee)$
	///i

	import: ///
		(\S*)					# prior content
		(\s*)					# prior whitespace
		import					# import declaration
		\s*						# whitespace after import declaration
		(?:\{(.+)\})?			# conditionals
		\s*						# whitespace after conditional
		(.+)					# filepath
	///g










module.exports = regEx