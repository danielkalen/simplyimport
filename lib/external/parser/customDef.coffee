def = require('ast-types').Type.def

def('Content')
	.bases 'Expression', 'Statement'
	.build 'content'
	.field 'content', String

def('ProgramContent')
	.bases 'Expression', 'Statement'
	.build 'content'
	.field 'content', def('Node')


require('ast-types').finalize()