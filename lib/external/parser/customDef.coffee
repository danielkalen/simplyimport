def = require('ast-types').Type.def

def('Content')
	.bases 'Expression'
	.build 'content'
	.field 'content', String


require('ast-types').finalize()