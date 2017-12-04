helpers = require './helpers'
{assert, expect, temp, runCompiled, emptyTemp, SimplyImport} = helpers

suite "sass", ()->
	test "imports will be inlined", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.sass': """
						.abc
							font-weight: 500
							color: black

						.def
							color: white
							@import './nested'

						@import "./ghi"
						@import './jkl'
					"""
					'ghi.sass': """
						.ghi
							opacity: 1
					"""
					'jkl.sass': """
						.jkl
							opacity: 0.5
					"""
					'nested/index.sass': """
						.def-child
							height: 300px
							importInline 'other'
					"""
					'nested/other.sass': """
						.other-child
							height: 400px
					"""

			.then ()-> SimplyImport file:temp('main.sass')
			.then (compiled)->
				assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
				assert.include compiled, '.def-child'
				assert.include compiled, 'height: 300px'
				assert.include compiled, '.other-child'
				assert.include compiled, 'height: 400px'
				assert.include compiled, '.ghi'
				assert.include compiled, 'opacity: 1'
				assert.include compiled, '.jkl'
				assert.include compiled, 'opacity: 0.5'

				css = null
				assert.doesNotThrow ()-> css = require('node-sass').renderSync(data:compiled, indentedSyntax:true).css.toString()
				Promise.resolve()
					.then ()-> require('modcss')(temp('main.css'), {})
					.then (stream)-> require('get-stream') require('streamify-string')(css).pipe(stream)
					.then (result)-> runCompiled('css.js', result, {module:{}})
					.then (tree)->
						assert.deepEqual tree,
							'.abc':
								fontWeight: '500'
								color: 'black'
							
							'.def':
								color: 'white'
							
							'.def .def-child':
								height: '300px'
							
							'.def .def-child .other-child':
								height: '400px'
							
							'.ghi':
								opacity: '1'
							
							'.jkl':
								opacity: '0.5'









