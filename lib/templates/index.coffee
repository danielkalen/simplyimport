Template = require './template'
returnSelf = (v)-> v or ''


exports.iife = new Template
	body: """
		(function(ARGS){
			BODY
		}).call(VALUES)
	"""
	placeholders:
		ARGS: (v)-> v.join ','
		VALUES: (v)-> ['this'].concat(v).join ','
		BODY: returnSelf



exports.loaderBrowser = new Template
	body: """
		LOADER = (function(cache,modules,cx){
			return function(r){
				if (!modules[r]) throw new Error(r+' is not a module')
				return cache[r] ? cache[r].exports
								: ( cache[r]={exports:{}}, cache[r].exports=modules[r].call(cx, LOADER, cache[r], cache[r].exports) );
			};
		})({},{},this);
	"""
	placeholders:
		LOADER: returnSelf


exports.loaderNode = new Template
	body: """
		LOADER = (function(cache,modules,cx,nativeRequire){
			return function(r){
				if (!modules[r]) return nativeRequire(r)
				return cache[r] ? cache[r].exports
								: ( cache[r]={exports:{}}, cache[r].exports=modules[r].call(cx, LOADER, cache[r], cache[r].exports) );
			};
		})({},{},this,require);
	"""
	placeholders:
		LOADER: returnSelf


exports.globalDec = new Template
	body: """
		typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : this
	"""


exports.umd = new Template
	body: """
		if (typeof define === 'function' && define.umd) {
			define(function(){return LOADER(ENTRY_ID)})
		} else if (typeof module === 'object' && module.exports) {
			module.exports = LOADER(ENTRY_ID)
		} else {
			return this['NAME'] = LOADER(ENTRY_ID)
		}
	"""
	placeholders:
		LOADER: returnSelf
		NAME: returnSelf
		ENTRY_ID: returnSelf


# exports.OFFSETS = 
# 	bundle: 1
# 	loader: 7
# 	module: 2











