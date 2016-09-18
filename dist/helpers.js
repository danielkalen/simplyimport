// Generated by CoffeeScript 1.10.0
var fs, helpers, path, regEx;

fs = require('fs');

path = require('path');

regEx = require('./regex');

helpers = {
  getNormalizedDirname: function(inputPath) {
    return path.normalize(path.dirname(path.resolve(inputPath)));
  },
  simplifyPath: function(inputPath) {
    return inputPath.replace(process.cwd() + '/', '');
  },
  testForComments: function(line, file) {
    if (file.isCoffee) {
      return line.includes('#');
    } else {
      return line.includes('//');
    }
  },
  commentOut: function(line, file, isImportLine) {
    var comment;
    comment = file.isCoffee ? '#' : '//';
    if (isImportLine) {
      return this.commentBadImportLine(line, comment);
    } else {
      return comment + " " + line;
    }
  },
  commentBadImportLine: function(importLine, comment) {
    return importLine.replace(regEx.importOnly, function(importDec) {
      return comment + " " + importDec;
    });
  },
  normalizeFilePath: function(inputPath, context) {
    var pathWithContext;
    inputPath = inputPath.replace(/['"]/g, '').replace(/\s+$/, '');
    pathWithContext = path.normalize(context + '/' + inputPath);
    return pathWithContext;
  },
  testConditions: function(allowedConditions, conditionsString) {
    var condition, conditions, i, len;
    conditions = conditionsString.split(/,\s?/).filter(function(nonEmpty) {
      return nonEmpty;
    });
    for (i = 0, len = conditions.length; i < len; i++) {
      condition = conditions[i];
      if (!allowedConditions.includes(condition)) {
        return false;
      }
    }
    return true;
  }
};

module.exports = helpers;
