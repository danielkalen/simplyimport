// Generated by CoffeeScript 1.10.0
var EMPTYHASH, File, SimplyImport, chalk, coffeeCompiler, consoleLabels, defaultOptions, extend, helpers, path, regEx, replaceImports, uglifier;

require('array-includes').shim();

path = require('path');

chalk = require('chalk');

extend = require('extend');

coffeeCompiler = require('coffee-script');

uglifier = require('uglify-js');

helpers = require('./helpers');

regEx = require('./regex');

defaultOptions = require('./defaultOptions');

consoleLabels = require('./consoleLabels');

File = require('./FileConstructor');

EMPTYHASH = "d41d8cd98f00b204e9800998ecf8427e";

SimplyImport = function(input, passedOptions, passedState) {
  var hash, processedContent, subjectFile, trackingInfo;
  this.options = extend({}, defaultOptions, passedOptions);
  subjectFile = new File(input, passedState);
  if (!subjectFile.content) {
    throw new Error(consoleLabels.error + " Import process failed - invalid input " + (chalk.underline.magenta(subjectFile.filePath)));
  } else {
    processedContent = replaceImports(subjectFile);
    if (this.options.track) {
      trackingInfo = ((function() {
        var results;
        results = [];
        for (hash in subjectFile.importHistory) {
          results.push(hash);
        }
        return results;
      })()).filter(function(hash) {
        return !subjectFile.trackedImportHistory[hash];
      }).map(function(hash) {
        return helpers.commentOut("SimplyImported -" + hash + "-", subjectFile);
      }).join('\n');
      processedContent = trackingInfo + "\n" + processedContent;
    }
    return processedContent;
  }
};

SimplyImport.scanImports = function(filePath, pathOnly, pathIsContent, pathWithContext) {
  var context, dicoveredImports, fileContent, subjectFile;
  dicoveredImports = [];
  if (pathIsContent) {
    fileContent = filePath;
    context = '.';
  } else {
    subjectFile = new File(filePath);
    fileContent = subjectFile.content;
    context = subjectFile.context;
  }
  fileContent.split('\n').forEach(function(line) {
    return line.replace(regEx["import"], function(entireLine, priorContent, spacing, conditions, childPath) {
      childPath = helpers.normalizeFilePath(childPath, context);
      if (!pathWithContext) {
        childPath = childPath.replace(context + '/', '');
      }
      if (pathOnly) {
        return dicoveredImports.push(childPath);
      } else {
        return dicoveredImports.push({
          entireLine: entireLine,
          priorContent: priorContent,
          spacing: spacing,
          conditions: conditions,
          childPath: childPath
        });
      }
    });
  });
  return dicoveredImports;
};

replaceImports = function(subjectFile) {
  return subjectFile.content.split('\n').map(function(originalLine) {
    return originalLine.replace(regEx["import"], function(entireLine, priorContent, spacing, conditions, childPath) {
      var childContent, childFile, failedReplacement, importerPath, spacedContent;
      if (conditions == null) {
        conditions = '';
      }
      if (helpers.testForComments(originalLine, subjectFile)) {
        return originalLine;
      }
      failedReplacement = this.options.preserve ? helpers.commentOut(originalLine, subjectFile, true) : '';
      if (helpers.testConditions(this.options.conditions, conditions)) {
        childPath = helpers.normalizeFilePath(childPath, subjectFile.context);
        childFile = new File(childPath, {
          'isCoffee': subjectFile.isCoffee
        }, subjectFile.importHistory);
        if (subjectFile.importHistory[childFile.hash]) {
          if (!this.options.silent) {
            importerPath = chalk.dim(helpers.simplifyPath(subjectFile.importHistory[childFile.hash]));
            childPath = chalk.dim(helpers.simplifyPath(childPath));
            console.warn(consoleLabels.warn + " Duplicate import found " + childPath + " - originally imported from " + importerPath);
          }
        } else if (childFile.hash !== EMPTYHASH) {
          subjectFile.importHistory[childFile.hash] = subjectFile.filePath || 'stdin';
          childContent = childFile.content;
          if (this.options.recursive) {
            childContent = replaceImports(childFile);
          }
          if (priorContent && priorContent.replace(/\s/g, '') === '') {
            spacing = priorContent + spacing;
            priorContent = '';
          }
          if (spacing && !priorContent) {
            spacedContent = childContent.split('\n').map(function(line) {
              return spacing + line;
            }).join('\n');
            childContent = spacedContent;
          }
          switch (false) {
            case !(subjectFile.isCoffee && !childFile.isCoffee):
              childContent = helpers.formatJsContentForCoffee(childContent);
              break;
            case !(childFile.isCoffee && !subjectFile.isCoffee):
              if (this.options.compileCoffeeChildren) {
                childContent = coffeeCompiler.compile(childContent, {
                  'bare': true
                });
              } else {
                throw new Error(consoleLabels.error + " You're attempting to import a Coffee file into a JS file (which will provide a broken file), rerun this import with -C or --compile-coffee-children");
              }
          }
          if (this.options.uglify) {
            childContent = uglifier.minify(childContent, {
              'fromString': true,
              'compressor': {
                'keep_fargs': true,
                'unused': false
              }
            }).code;
          }
        }
      }
      if (priorContent && childContent) {
        childContent = priorContent + spacing + childContent;
      }
      return childContent || failedReplacement;
    });
  }).join('\n');
};

module.exports = SimplyImport;