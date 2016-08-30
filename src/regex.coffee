regEx = 
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(js|coffee)$			# Extension
	///i

	import: ///^
		(?:
			(.*)				# prior content
			(\s+)				# prior space
				|				# or if above aren't present
			\W?					# no letters
		)
		import					# import declaration
		\s+						# whitespace after import declaration
		(?:\[(.+)\])?			# conditionals
		\s*						# whitespace after conditional
		(.+)					# filepath
	///g

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










module.exports = regEx