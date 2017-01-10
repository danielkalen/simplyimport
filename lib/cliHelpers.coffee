minimist = require 'minimist'
regEx = require './regex'

module.exports = 
	normalizeTransformOpts: (transforms)-> if transforms
		transforms = [].concat(transforms)
		transforms.map (transform)->
			if regEx.hasSquareBrackets.test(transform)
				transform = transform.match(regEx.bracketContents)[1]
				transformer = transform.match(regEx.firstWord)[1]
				opts = transform.split(/\s+/)
				opts = minimist(opts)
				return [transformer, opts]
			else
				return transform


	exitWithHelpMessage: ()->
		process.stdout.write(require('yargs').help());
		process.exit(1)