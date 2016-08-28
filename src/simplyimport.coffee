if not Array::includes then Array::includes = (subject)-> @indexOf(subject) isnt -1
path = require 'path'
CoffeeCompiler = require 'coffee-script'
Uglifier = require 'uglify-js'
helpers = require './helpers'
regEx = require './regex'
File = require './FileConstructor'






processMainFile = (input, passedOptions, passedState)->
	subjectFile = new File(input, passedOptions, passedState)

	if not subjectFile.content
		console.error "Import process failed - invalid input #{subjectFile.filePath}"
		return process.exit(1);
	else
		return replaceImports(subjectFile) or subjectFile.content
	




replaceImports = (subjectFile)->
	subjectFile.content
		.split '\n'
		.map((originalLine)-> originalLine.replace regEx.import, (originalLine, priorContent, spacing='', conditions='', childPath)->
			return originalLine if helpers.testForComments(originalLine, subjectFile)
			failedReplacement = if subjectFile.options.preserve then helpers.commentOut(originalLine, subjectFile) else ''
			
			if helpers.testConditions(subjectFile.options.conditions, conditions)
				childPath = helpers.normalizeFilePath(childPath, subjectFile.context)
				
				unless subjectFile.importHistory[childPath]
					subjectFile.importHistory[childPath] = true
					childFile = new File childPath, subjectFile.options, {'isCoffee':subjectFile.isCoffee}, subjectFile.importHistory
					childContent = childFile.content or ''

					if childContent
						# ==== Child Imports =================================================================================
						if subjectFile.options.recursive
							childContent = replaceImports(childFile)


						# ==== Spacing =================================================================================
						if spacing and spacing isnt '\n' and not priorContent
							spacing = spacing.replace /^\n*/, '' # Strip initial new lines
							spacedContent = childContent
								.split '\n'
								.map (line)-> spacing+line
								.join '\n'
							
							childContent = '\n'+spacedContent


						# ==== JS vs. Coffeescript conflicts =================================================================================
						switch
							when subjectFile.isCoffee and not childFile.isCoffee
								childContent = childContent.replace /^(\s*)((?:.|\n)+)/, (entire, spacing='', content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
									escapedContent = content.replace /`/g, ()-> '\\`'
									"#{spacing}`#{escapedContent}`"
							

							when childFile.isCoffee and not subjectFile.isCoffee
								if subjectFile.options.compileCoffeeChildren
									CoffeeCompiler.compile childFile.content, 'bare':true
								else
									throw new Error("You're attempting to import a Coffee file into a JS file (which will provide a broken file), rerun this import with --compile-coffee-children")
									process.exit(1)

						
						# ==== Minificaiton =================================================================================								
						if subjectFile.options.uglify
							childContent = Uglifier.minify(childContent, {'fromString':true}).code


			if priorContent and childContent
				childContent = priorContent + spacing + childContent

			return childContent or failedReplacement
		
		).join '\n'




























module.exports = processMainFile