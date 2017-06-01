EXTENSIONS = require '../constants/extensions'

module.exports = relatedExtensions = (ext)-> switch
	when EXTENSIONS.js.includes(ext) then EXTENSIONS.js
	when EXTENSIONS.css.includes(ext) then EXTENSIONS.css
	when EXTENSIONS.html.includes(ext) then EXTENSIONS.html
	when EXTENSIONS.data.includes(ext) then EXTENSIONS.data
	else EXTENSIONS.none