REGEX = 
	es6memberAlias: /\s+as\s+/
	quotes: /['"]/
	commaSeparated: /,\s*/
	squareBrackets: /[\[\]]/
	curlyBrackets: /[\{\}]/
	stringContents: /".+?"|'.+?'/g
	bracketContents: /\[\s*(.+?)\s*\]/
	hasSquareBrackets: /\[.+?\]/
	firstWord: /^(\S+)/
	# singleBracketEnd: /^[^\(]*\)/
	# useStrict: /["']use strict["'];\n\n/
	ignoreStatement: /simplyimport:ignore/g
	# newLine: /\r?\n/
	# startingNewLine: /^\n+/
	initialWhitespace: /^[ \t]+/
	# thisKeyword: /\bthis\b|\@/
	requireArg: /\brequire[,\)]/
	processRequire: /\brequire[\(\s]['"]process['"]\)?/
	processDec: /\bprocess\s?=\s?/
	globalCheck: /typeof global\b[^\.\[]/
	moduleCheck: /typeof module\s?[\!=]==|=typeof module|if module\?/
	defineCheck: /typeof define\s?[\!=]==|=typeof define|if define\?/
	requireCheck: /typeof require\s?[\!=]==|=typeof require|if require\?/
	exportsCheck: /typeof exports\s?[\!=]==|=typeof exports|if exports\?/

	vars:
		global: /\bglobal\b/
		exports: /\bexports\b/
		process: /\bprocess\./
		__dirname: /\b\_\_dirname\b/
		__filename: /\b\_\_filename\b/
		# require: /\brequire[\(\s]/
	

	# fileContent: ///^
	# 	(\s*)					# Whitespace
	# 	(
	# 		(?:\w|\W)+			# All content
	# 	)
	# ///

	# escapedNewLine: ///
	# 	\\						# Escape literal
	# 	\n 						# Newline
	# ///g


	customImport: ///^
		(
			.*					# prior content
			[\ \t\r=]+			# prior space (excluding new line)
			\W?					# no letters
				|				# or if above aren't present
			\W?					# no letters
		)
		(
			import					# import keyword
			\s+						# whitespace after import keyword
		)
		(?:\[(.+)\])?			# conditionals
		(
			\s*						# whitespace after conditional
		)
		(?!
			\{.+\}
				|
			\ from
		)
		(\S+?)					# filepath
		(\).*?|\s*?)			# trailing whitespace/parentheses
	$///gm

	es6import: ///
		(
			[\ \t\r=]* 			# prior whitespace
		)
		(
			import				# import keyword
			\s+					# whitespace after import keyword
		)
		(
			(?:
				([^\*,\{\s]+) 	# default member
				,?\ ?			# trailing comma
			)?
			(
				\*\ as\ \S+		# all members
					|
				\{.+\} 			# specific members
			)?
			\ from
			\s*					# whitespace after members
		)
		(\S+?)					# filepath
	$///gm


	pugImport: ///^
		(
			.*					# prior content
			\W?					# no letters
				|				# or if above aren't present
			\W?					# no letters
		)
		include					# import keyword
		\s+						# whitespace after import keyword
		(\S+?)					# filepath
	$///gm


	cssImport: ///^
		(
			.*					# prior content
			\W?					# no letters
				|				# or if above aren't present
			\W?					# no letters
		)
		@import					# import keyword
		\s+						# whitespace after import keyword
		(\S+?)					# filepath
	$///gm


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

	commonExport: ///^
		(.+[\ \t\r]|.+\;|)								# prior content
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
		)
		(.*) 											# trailing content
	$///

	commonImport: ///^
		\b
		require 										# require reference
		\( 												# trailing char after 'require' (bracket open)
		\s*
		(.+)
		\) 												# trailing char after 'require' (bracket close)
	$///

	commonImportReal: ///^
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
	$///


	comment:
		singleLine: /([^:]|^)\/\/(.*)$/mg
		multiLine: /(^|[^\\])(\/\*([\s\S]*?)\*\/)/mg

	










module.exports = REGEX