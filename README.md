# SimplyImport
The `require` module system is great and all, but sometimes all we want to do is just import a separate file as is like it was written inside the importing file without the hassle of writing `module.exports` declarations and annoying `require` declarations. After using SASS's @import and PHP's include/require, I realized the importance of modularity and keeping code files small for the sake of usability and sanity. Browserify, AMD, CommonJS, etc. are a great solution for javascript modularity but sometimes they are just way too complex and require way too much work than needed in order to implement.

Keep in mind that the aformentioned module systems **are probably more semantic** and would probably be considered more profesisonal, but this import concept takes a more simplictic approach that is easier and faster to implement and is just offered as an **addition** to your current module workflow, not necessarily a replacement.

With SimplyImport you can:

* implement a simpler and faster modular system than the currently available methods.
* split huge files into bits and pieces to keep your sanity in place.
* eliminate the need to search through thousands of lines everytime you need to reference/change something.
* and much more...

## Example:
Command Line:
```
simplyimport -i src/main.js -o dist/main.compiled.js -u

// Supports Coffeescript with '#' comments instead of '//'
simplyimport -i src/main.coffee -o dist/main.compiled.coffee -u
```

Node module:
**nesteddir/foo.js**
```javascript
var foo = 'foo';
```

**nesteddir2/baz.js**
```javascript
var baz = 'baz';
```

**nesteddir3/qux.js**
```javascript
var qux = 'qux';
```

**main.js**
```javascript
var concatStrings = function(arg1, arg2){return arg1+' bar '+arg2};

// @import 'nesteddir/foo.js'
// @import nesteddir2/baz.js

concatStrings(foo, baz);

// @import nesteddir3/qux

concatStrings(foo, qux);
```

**Compiled main.js**
```javascript
var concatStrings = function(arg1, arg2){return arg1+' bar '+arg2};

var foo = 'foo';
var baz = 'baz';

concatStrings(foo, baz); // outputs "foo bar baz"

var qux = 'qux';

concatStrings(foo, qux); // outputs "foo bar qux"
```



## Usage:
**Command Line**
```
simplyimport -i <input> -o [<output>|<outputdir>] -[u|s|n]
```

**Node Module**
```javascript
var SimplyImport = require('simplyimport');

// Compile by filename (writes compiled file to the second argument)
SimplyImport('src/foo.js', 'dist/foo.compiled.js', {shouldUglify: true});

// Compile by string (returns compiled string)
fs.readFile('foo/bar.js', function(err, data){
  var compiled = SimplyImport(data);
  console.log(compiled) // Logs out the compiled data with all its @import directives attended.
});
```

**Command Line Options:**

```bash
    -i, --input   <path>        Path of the file to compile. Can be relative or absolute.
    -o, --output  <path>        Path to write the compiled file to. Can be a file, or directory. If omitted the compiled result will be written to stdout.
    -s, --stdout                Output the compiled result to stdout. (Occurs by default if no output argument supplied)
    -u, --uglify                Uglify/minify the compiled file.
    -n, --notrecursive          Don't attend/follow @import directives inside imported files.
    -h, --help                  Print usage info.
```
