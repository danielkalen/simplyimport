registerModule = (moduleName)->
	Object.defineProperty module.exports, moduleName,
		configurable: true
		get: ()->
			result = require "./#{moduleName}"
			delete module.exports[moduleName]
			module.exports[moduleName] = result
			return result

registerModule 'getNormalizedDirname'
registerModule 'simplifyPath'
registerModule 'changeExtension'
registerModule 'relatedExtensions'
registerModule 'resolveEntryPackage'
registerModule 'resolveFilePath'
registerModule 'resolveModulePath'
registerModule 'resolveHttpModule'
registerModule 'resolveTransformer'
registerModule 'resolveAlias'
registerModule 'resolvePackageEntry'
registerModule 'resolvePlaceholders'
registerModule 'normalizeTargetPath'
registerModule 'normalizePackage'
registerModule 'normalizeTransforms'
registerModule 'safeRequire'
registerModule 'runTransform'
registerModule 'randomVar'
registerModule 'strToVar'
registerModule 'prepareMultilineReplacement'
registerModule 'newPathConfig'
registerModule 'newExportStatement'
registerModule 'newImportStatement'
registerModule 'newForceInlineStatement'
registerModule 'collectRequires'
registerModule 'collectImports'
registerModule 'collectExports'
registerModule 'namedError'
registerModule 'blankError'
registerModule 'annotateErrLocation'
registerModule 'splitContentByStatements'
registerModule 'matchNestingStatement'
registerModule 'matchConditional'
registerModule 'matchGlob'
registerModule 'matchFileSpecificOptions'
registerModule 'isMixedExtStatement'
registerModule 'isLocalModule'
registerModule 'isRecursiveImport'
registerModule 'isStream'
registerModule 'isHttpModule'
registerModule 'isValidTransformerArray'
registerModule 'isMatchPath'
registerModule 'applySourceMapToAst'
registerModule 'applyForceInlineSourceMap'
registerModule 'path'
registerModule 'temp'