helpers = require './helpers'
{assert, expect, temp, emptyTemp, SimplyImport} = helpers

suite "pug/jade", ()->
	test "imports will be inlined", ()->
		Promise.resolve()
			.then emptyTemp
			.then ()->
				helpers.lib
					'main.pug': """
						html
							head
								include './meta'
								link(rel='stylesheet', href='/index.css')
								include './scripts'
							
							importInline './body'
					"""
					'meta/index.jade': """
						include './a'
						importInline './importB'
						include 'c'
					"""
					'meta/a.jade': """meta(name="content", value="a.jade")"""
					'meta/b.pug': """meta(name="content", value="b.pug")"""
					'meta/c.jade': """meta(name='content', value='c.jade')"""
					'meta/importB.pug': """include 'b'"""
					'scripts.pug': """
						script(src="/a.js")
						script(src="/b.js")
					"""
					'body.jade': """
						body
							main
								div
									span='firstSpan'
									span=include 'spanText'
									span='lastSpan'
					"""
					'spanText.pug': "'abc123'"

			.then ()-> SimplyImport file:temp('main.pug')
			.then (compiled)->
				assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
				assert.include compiled, 'meta(name="content", value="a.jade")'
				assert.include compiled, 'meta(name="content", value="b.pug")'
				assert.include compiled, "meta(name='content', value='c.jade')"
				assert.include compiled, 'script(src="/a.js")'
				assert.include compiled, "span='abc123'"
				assert.notInclude compiled, "spanText"
				
				html = null
				assert.doesNotThrow ()-> html = require('pug').render(compiled)
				tree = require('html2json').html2json(html)

				adjust = (node)->
					delete node.node if node.node isnt 'root'
					return if not node.child
					adjust(child) for child in node.child
					return
				
				adjust(tree)
				assert.deepEqual tree,
					node: 'root'
					child: [
						tag: 'html'
						child: [
							tag: 'head'
							child: [
								tag: 'meta'
								attr: {name:'content', value:'a.jade'}
							,
								tag: 'meta'
								attr: {name:'content', value:'b.pug'}
							,
								tag: 'meta'
								attr: {name:'content', value:'c.jade'}
							,
								tag: 'link'
								attr: {rel:'stylesheet', href:'/index.css'}
							,
								tag: 'script'
								attr: {src:'/a.js'}
								child: [text:'']
							,
								tag: 'script'
								attr: {src:'/b.js'}
								child: [text:'']
							]
						,
							tag: 'body'
							child: [
								tag: 'main'
								child: [
									tag: 'div'
									child: [
										tag: 'span'
										child: [text:'firstSpan']
									,
										tag: 'span'
										child: [text:'abc123']
									,
										tag: 'span'
										child: [text:'lastSpan']
									]
								]
							]
						]
					]









