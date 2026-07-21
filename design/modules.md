
# Modules

The module system works using the filesystem structure. To export a name to be used across modules, use the caret '^' symbol.
Unexported symbols will still be visible inside its own module. `main` function are always private to its own file, 
and cannot be exported, any file that is run by the interpreter will execute its file's main function.

Circular dependencies are not allowed.

All files are singular module by default, with their filename as the module name. 
They can import anything inside their own folder. To import, use the `use` keyword.

```luv
# inside src/file1.luv

def ^importantNumber = 1

# inside src/file2.luv

use file1

def hiddenNumber = file1.importantNumber + 1
```

`use` can alias a module name.

```luv
use importedFile "1"
```

## Multi-file module

A file can join other module inside its own folder using the `mod` keyword with the same module name across the files. 
Redefinition of symbols is not allowed inside the same module, with the exception of the `main` function (file-private always).

```luv
#inside src/file1.luv

mod utils

def a = 10

#inside src/file2.luv

mod utils

# def a = 20 Error!

def b = a + 10
```

## Subfolder Module

A Subfolder have public access for all of the modules inside. A subfolder is importable, it will import all the modules inside it non-recursively.

```luv
#inside src/utils/file1.luv

def ^a = 1

#inside src/utils/file2.luv

fun ^id[T any](t T) T { return t }

#inside src/main.luv

use a "utils/file1"
use "utils/file2" # will follow the module name File2.a
use utils # accessible via utils.file1, utils.file1
```

Name must be aliased if its not a valid `luv` identifier.

## Relative imports

For outside modules, `luv` support relative imports. It will match filepath that ends with the module path.

with a filesystem of
```
root/
| src/
| | main.luv
| utils/
| | tool.luv
```

in `main.luv` use "root/utils/tool" to access tool module. 
