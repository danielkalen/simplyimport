regEx = 
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(js|coffee)$			# Extension
	///i

	fileContent: ///^
		(\s*)					# Whitespace
		(
			(?:\w|\W)+			# All content
		)
	///

	escapedNewLine: ///
		\\						# Escape literal
		\n 						# Newline
	///g

	backTicks: ///
		`
	///g

	preEscapedBackTicks: ///
		\\						# Existing escapement
		`						# Backtick
	///g

	import: ///^
		(?:
			(.*)				# prior content
			([\ \t\r]+)			# prior space (excluding new line)
			\W?					# no letters
				|				# or if above aren't present
			\W?					# no letters
		)
		import					# import declaration
		\s+						# whitespace after import declaration
		(?:\[(.+)\])?			# conditionals
		\s*						# whitespace after conditional
		(\S+)					# filepath
		\s*
	$///gm

	importOnly: /// # Without prior content
		import					# import declaration
		\s*						# whitespace after import declaration
		(?:\[(.+)\])?			# conditionals
		\s*						# whitespace after conditional
		(.+)					# filepath
	///g


	trackedImport: ///
		(?:\/\/|\#)				# comment declaration
		\sSimplyImported\s		# simplyimport label
		\-						# hash start indicator
		(.{32}) 				# actual hash
		\-						# hash end indicator
	///g


	# comment: /(^|[^\\])\/\*([\s\S]*?)\*\/|([^:]|^)\/\/(.*)$/mg
	comment:
		singleLine: /([^:]|^)\/\/(.*)$/mg
		multiLine: /(^|[^\\])(\/\*([\s\S]*?)\*\/)/mg

	commonJS:
		export: /(?:^\uFEFF?|[^$_a-zA-Z\xA0-\uFFFF.])(exports\s*(\[['"]|\.)|module(\.exports|\['exports'\]|\["exports"\])\s*(\[['"]|[=,\.]))/
		import: /(?:^\uFEFF?|[^$_a-zA-Z\xA0-\uFFFF."'])require\s*\(?\s*("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')\s*\)?/

	es6: /(^\s*|[}\);\n]\s*)(import\s*(['"]|(\*\s+as\s+)?[^"'\(\)\n;]+\s*from\s*['"]|\{)|export\s+\*\s+from\s+["']|export\s*(\{|default|function|class|var|const|let|async\s+function))/

	AMD: /(?:^\uFEFF?|[^$_a-zA-Z\xA0-\uFFFF.])define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*\s*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/
	










module.exports = regEx