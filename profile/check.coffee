require('sugar').extend()
fs = require 'fs-jetpack'
FILE = './cpu.cpuprofile'
profile = fs.read FILE, 'json'


nodeExists = ((id)->
	!!profile.nodes.find({id})
).memoize()

missingSamples = profile.nodes
	.filter (node)-> !nodeExists(node.id)

for sample,index in profile.samples
	if not nodeExists(sample)
		console.log "SAMPLE index:#{index} id:#{sample}"

for node in profile.nodes
	for child in node.children
		if not nodeExists(child)
			console.log "CHILD childID:#{child} parentID:#{node.id}"

