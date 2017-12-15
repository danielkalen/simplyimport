def = require('ast-types').Type.def

def('Content')
	.bases 'Expression', 'Statement'
	.build 'content'
	.field 'content', String

def('ContentGroup')
	.bases 'Expression', 'Statement'
	.build 'body'
	.field 'body', [def('Content')]

def('ProgramContent')
	.bases 'Expression', 'Statement'
	.build 'content'
	.field 'content', def('Node')


require('ast-types').finalize()