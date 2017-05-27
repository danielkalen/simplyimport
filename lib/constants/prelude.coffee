exports.bundle = """
(function(){
	return _s$m(0);
}).call(this)
"""

exports.loader = """
var _s$m = (function(modules,cache,loaded,_s$m){
	return function(r,module){
		return loaded[r] ? cache[r]
					: (loaded[r]=1, module={exports: cache[r]={}}, cache[r]=modules[r]( module,cache[r] ));
	};
})({},{},{});
"""


exports.module = """
	function(module, exports){
		return module.exports;
	}
"""















