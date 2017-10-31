REGEX = 
	quotes: /['"]/
	extractDelim: /\s*\$\s*/
	endingSemi: /;$/
	bracketStart: /^[\{\[\(]$/
	bracketEnd: /^[\}\]\)]$/
	squareBrackets: /[\[\]]/
	curlyBrackets: /[\{\}]/
	bracketContents: /\[\s*(.+?)\s*\]/
	hasSquareBrackets: /\[.+?\]/
	firstWord: /^(\S+)/
	shebang: /^#![^\n]*\n/
	pathPlaceholder: /%([A-Z]+)/
	varIncompatible: /[^0-9a-zA-Z_$]/g
	initialWhitespace: /^[ \t]+/
	initialExport: /^module\.exports\s*=\s*/
	decKeyword: /var|let|const/
	requireArg: /\brequire[,\)]/
	requireDec: /\bfunction require\b/
	processDec: /\brequire[\(\s]['"]process['"]\)?|\bprocess\s?=\s?/
	bufferDec: /\brequire[\(\s]['"]buffer['"]\)?|\bBuffer\s?=\s?/
	globalCheck: /typeof global\b[^\.\[]/
	moduleCheck: /typeof module\s?[\!=]==|=typeof module|if module\?/
	defineCheck: /typeof define\s?[\!=]==|=typeof define|if define\?/
	requireCheck: /typeof require\s?[\!=]==|=typeof require|if require\?/
	exportsCheck: /typeof exports\s?[\!=]==|=typeof exports|if exports\?/

	vars:
		global: /\bglobal\b/
		exports: /\bexports\b/
		buffer: /\bBuffer\b/
		process: /\bprocess\b/
		__dirname: /\b\_\_dirname\b/
		__filename: /\b\_\_filename\b/
		# require: /\brequire[\(\s]/
	
	ifStartStatement: /simplyimport:if\s+(.+)/g
	ifEndStatement: /simplyimport:end/g

	inlineImport: ///
		\b
		importInline		# import keyword
		\s+					# whitespace after import keyword
		(
			".*?"
				|
			'.*?'
		)
	///g



	# es6import: ///
	# 	(
	# 		[\ \t\r=]* 			# prior whitespace
	# 	)
	# 	(
	# 		import				# import keyword
	# 		\s+					# whitespace after import keyword
	# 	)
	# 	(
	# 		(?:
	# 			([^\*,\{\s]+) 	# default member
	# 			,?\ ?			# trailing comma
	# 		)?
	# 		(
	# 			\*\ as\ \S+		# all members
	# 				|
	# 			\{.+\} 			# specific members
	# 		)?
	# 		\ from
	# 		\s*					# whitespace after members
	# 	)
	# 	(\S+?)					# filepath
	# $///gm

	es6import: ///
		\b
		import					# import keyword
		\s+						# whitespace after import keyword
		(
			(
				[^\*,\{\s]+ 	# default member
				,?\ ?			# trailing comma
			)?
			(
				\*\ as\ \S+		# all members
					|
				\{.+\} 			# specific members
			)?
			\ from
			\s+					# whitespace after members
		)?
		(
			".+?"
				|
			'.+?'
		)
	///g

	tempImport: ///
		\b
		_\$sm
		\(
		(
			".+?"
				|
			'.+?'
		)
		(?:
			,\s*
			(
				".+?"
					|
				'.+?'
			)
		)?
		\s*
		\)
	///g


	pugImport: ///
		\b
		include					# import keyword
		\s+						# whitespace after import keyword
		(.+)					# filepath
	///g


	cssImport: ///
		@import					# import keyword
		\s+						# whitespace after import keyword
		(.+)					# filepath
	///g

	# tsExport: ///
	# 	\bexport\s+=\s*
	# ///

	es6export: ///^
		(
			[\ \t\r=]* 			# prior whitespace
		)
		export
		\s+
		(?:
			(\{.+\}) 										# export mapping
				|
			(default|function\*?|class|var|const|let) 		# export type
			\s+ 											# spacing
			(\S+)? 											# item label
		)?
		(.*) 												# trailing content
	$///gm

	commonExport: ///
		\b
		(?:
			exports\s* 									# plain exports variable
				|
			(?: 										# module.exports variable variations
				module
				(?:
					\.exports
						|
					\['exports'\]
						|
					\["exports"\]
				)
				\s* 									# variable-access trailing whitespace
			)
		)
		(
			\[ 											# property string-notation access
				|
			[=\.] 										# property dot-notation access
		)?
	///m


	commonImportReal: ///
		\b
		require 										# require reference
		\( 												# trailing char after 'require' (bracket open)
		\s*
		(
			".*?"
				|
			'.*?'
		)
		\) 												# trailing char after 'require' (bracket close)
	///

	defaultExport: ///
		\b
		exports
		(?:
			\.
			default
				|
			\[
			['"]
			default
			['"]
			\]
		)
		\s*
		=
	///

	










module.exports = REGEX