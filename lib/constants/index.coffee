Path = require 'path'
exports.EMPTY_FILE_END = EMPTY_FILE_END = Path.join('node_modules','browser-resolve','empty.js')
exports.EMPTY_FILE = EMPTY_FILE = Path.resolve(__dirname,'..','..',EMPTY_FILE_END)
exports.EMPTY_STUB = EMPTY_STUB = Path.join __dirname,'..','..','empty.js'