parser = require '../external/parser'
# extend = require 'extend'
# cache = Object.create(null)

class Template
	constructor: ({@body, @placeholders})-> ;

	build: (values)->
		output = @body
		
		if @placeholders
			for placeholder,format of @placeholders
				output = replace output, placeholder, format(values[placeholder])

		return output

	ast: (values)->
		parser.parse @build(values)
		# parse @build(values)
		# extend true, {}, parse @build(values)


replace = (string, target, value)->
	while string.indexOf(target) isnt -1
		string = string.replace target, value
	return string


# parse = (string)->
# 	if cache[string]
# 		return cache[string]
# 	else
# 		return parser.parse(string)




module.exports = Template