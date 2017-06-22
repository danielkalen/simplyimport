minimist = require 'minimist'
REGEX = require '../constants/regex'

module.exports = 
	normalizeTransformOpts: (transforms)-> if transforms
		transforms = [].concat(transforms)
		transforms.map (transform)->
			if REGEX.hasSquareBrackets.test(transform)
				transform = transform.match(REGEX.bracketContents)[1]
				transformer = transform.match(REGEX.firstWord)[1]
				opts = transform.split(/\s+/)
				opts = minimist(opts)
				return [transformer, opts]
			else
				return transform


	exitWithHelpMessage: ()->
		process.stdout.write(require('yargs').help());
		process.exit(1)