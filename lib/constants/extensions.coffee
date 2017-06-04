module.exports = extensions = {}

extensions.compat = [
	'js'
	'css'
	'html'
	'json'
]

extensions.js = [
	'js'
	'jsx'
	'ts'
	'tsx'
	'ls'
	'coffee'
	'iced'
]

extensions.data = [
	'json'
	'cson'
	'yml'
]

extensions.css = [
	'css'
	'scss'
	'sass'
	'less'
	'stylus'
]

extensions.html = [
	'html'
	'jade'
	'pug'
]

extensions.none = []

extensions.nonJS = extensions.none.concat(
	extensions.data
	extensions.css
	extensions.html
)

extensions.static = extensions.none.concat(
	extensions.css
	extensions.html
)

extensions.all = extensions.none.concat(
	extensions.js
	extensions.data
	extensions.css
	extensions.html
)

