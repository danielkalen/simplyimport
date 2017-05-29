exports.bundle = (args, values, returnResult)-> """
(function(#{args.join(',')}){
	#{returnResult}
}).call(#{['this'].concat(values).join(',')})
"""

exports.loader = ()-> """
var _s$m = (function(modules,cache,loaded){
	return function(r,module){
		return loaded[r] ? cache[r]
					: (loaded[r]=1, module={exports: cache[r]={}}, cache[r]=modules[r]( module,cache[r] ));
	};
})({},{},{});
"""


exports.module = ()-> """
	function(module, exports){
		return module.exports;
	}
"""

exports.moduleGlobals = (args, values)-> """
	(function(#{args.join(',')}){

	}).call(#{['this'].concat(values).join(',')})
"""

exports.globalDec = ()-> """
	typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {}
"""

exports.returnResult = ()-> """
	return _s$m(0)
"""

exports.umdResult = (name)-> """
	if (typeof define === 'function' && define.umd) {
		define(function(){return _s$m(0)})
	} else if (typeof module === 'object' && module.exports) {
		module.exports = _s$m(0)
	} else {
		return this['#{name}'] = _s$m(0)
	}
"""














