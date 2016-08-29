regEx = 
	fileExt: ///
		.+ 						# File name
		\. 						# Period separator
		(js|coffee)$			# Extension
	///i

	import: ///
		(\S*)					# prior content
		(\s*)					# prior whitespace
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