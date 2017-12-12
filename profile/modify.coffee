require('sugar').extend()
fs = require 'fs-jetpack'
args = require('minimist')(process.argv.slice(2))
FILE = "./#{args._[0] or 'cpu'}.cpuprofile"
profile = fs.read FILE, 'json'

Promise.resolve()
	.then ()->
		if args.fn then [].concat(args.fn).forEach (target)->
			iterate (node)->
				node.callFrame.functionName is target
			, removeNode
		
		if args.file then [].concat(args.file).forEach (target)->
			iterate (node)->
				node.callFrame.url.startsWith(target)
			, removeNode
		
		if args.notfile then [].concat(args.notfile).forEach (target)->
			iterate (node)->
				not node.callFrame.url.startsWith(target)
			, removeNode
		
		if args.simplepath then [].concat(args.simplepath).forEach (target)->
			iterate (node)->
				node.callFrame.url.startsWith(target)
			, (node)->
				node.callFrame.url = node.callFrame.url.replace args.simplepath, args.target or '.'

	.then ()-> fs.write FILE, profile


iterate = (filter, cb)->
	for node in profile.nodes.slice()
		cb(node) if filter(node)

removeNode = (node)->
	indeces = findNodeIndeces(node)
	parents = findNodeParents(node)

	profile.nodes.remove(node)
	for index in indeces.slice().reverse()
		profile.samples.removeAt(index)
		profile.timeDeltas.removeAt(index)

	for parent in parents
		index = parent.children.indexOf(node.id)
		parent.children.splice index, 1, node.children...

	return


findNodeIndeces = (node)->
	matches = []
	for sample,index in profile.samples
		matches.push(index) if sample is node.id
	return matches

findNodeParents = (node)->
	matches = []
	for parent in profile.nodes
		matches.push(parent) if parent.children.length and parent.children.includes(node.id)
	return matches
