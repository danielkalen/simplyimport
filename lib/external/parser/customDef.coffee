def = require('ast-types').Type.def

def('Content')
	.bases 'Expression', 'Statement'
	.build 'content'
	.field 'content', String


require('ast-types').finalize()