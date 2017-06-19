module.exports = (content)->
	content
		.replace /\n+/g, '\t'
		.replace /\t+/g, ' '