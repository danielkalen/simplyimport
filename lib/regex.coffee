regEx = 
	stringContents: /".+?"|'.+?'/g
	singleBracketEnd: /^[^\(]*\)/
	
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
		(?:
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
		)?
		\s*						# whitespace after members
		(\S+?)					# filepath
		(\).*?|\s*?)			# trailing whitespace/parentheses
	$///gm


	export: ///^
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

	commonJS:
		export: ///^
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
		$///gm

		import: ///^
			(.+[\ \t\r]|.+\;|)								# prior content
			require 										# require reference
			(
				\s+ | \( 									# trailing char after 'require' (either bracket or space)
			)
			\s*
			(
				".*?"
					|
				'.*?'
			)
			(?:
				\) | [^\n\S]? 									# trailing char after end of 'require' (either bracket or space)
			)
			(.*) 											# trailing content
		$///gm

		# import: /(^\uFEFF?|[^$_a-zA-Z\xA0-\uFFFF."'])require\s*\(?\s*("[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*')\s*\)?/


	# comment: /(^|[^\\])\/\*([\s\S]*?)\*\/|([^:]|^)\/\/(.*)$/mg
	comment:
		singleLine: /([^:]|^)\/\/(.*)$/mg
		multiLine: /(^|[^\\])(\/\*([\s\S]*?)\*\/)/mg


	# AMD: /(?:^\uFEFF?|[^$_a-zA-Z\xA0-\uFFFF.])define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*\s*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/
	










module.exports = regEx