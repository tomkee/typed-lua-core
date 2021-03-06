# Typed Lua Core Typechecker
[![Build Status](https://travis-ci.org/tomkee/typed-lua-core.svg?branch=master)](https://travis-ci.org/tomkee/typed-lua-core)

The idea of project is to use Haskell as another way of reasoning about the typing rules of Typed Lua. Project involves implementing parser and typechecker for Typed Lua Core.

**[Typed Lua](https://github.com/andremm/typedlua)** is a typed superset of Lua that compiles to plain Lua. It provides optional type annotations, compile-time type checking, and class-based object oriented programming through the definition of classes, interfaces, and modules.

**Typed Lua Core** is reduced version of Typed Lua prepared to present rules of Typed Lua type system. 

Typed Lua Core contains:
* multiple assignments
* local (typed and untyped) declarations
* if and while statements
* binary operations: +, .., ==, <, /, %, // 
* unary operations: #, not
* explicit type annotations
* tables
* functions and function calls
* explicit method declarations and calls
* table refinements
* type coercions
* recursive types

Typed Lua core does not support features and syntactic sugar as:
* labels and goto
* repeat-until, for
* table fields other than [ x ] = y
* arithmetic operators other than +, /, %, //
* relational operators other than == and <
* bitwise operators other than &
* unary opertors other than # and not

For more informations about TypedLua typesystem and Typed Lua Core syntax please read [Typed Lua: An Optional Type System for Lua](https://github.com/andremm/typedlua/blob/master/doc/thesis/thesis_andre_certified.pdf).


## Overview of project
Compilation can be divided into 3 phases:
1. Parsing
2. Resolving global variables
3. Typechecking

### 0. AST and type hierarchy
Typed Lua Core AST is quite similar to [Typed Lua AST](https://github.com/andremm/typedlua/blob/master/typedlua/tlast.lua). It can be found in file `src/AST.hs`.

Type hierarchy is implemented in file `src/Types.hs`.


### 1. Parsing
Parsing is done with haskell [trifecta](https://hackage.haskell.org/package/trifecta) library.

Source code of type parser can be found in `src/Parser/Types.hs`. 

Typed lua core expressions and statements parser is implemented in file `src/Parser/Code.hs`.

### 2. Resolving global variables
Typed lua core supports only local variable declarations. All global variables are in fact members of unique table `_ENV`. Because of this all reads and writes of global variables should be translated to table access.
In example:
`b = 1`
should be translated to:
`_ENV["b"] = 1`.

Moreover global table `_ENV` should be declared explicitly in top, local scope:
```
local _ENV:{"a":integer, "b":integer} = {["a"] = 1, ["b"] = 1}
in b = a * b
```

Because of this I implemented compiler pass called **Globals transformation** which was detecting global variables and transforming them to global table access.
Source code of **global transformation** can be found in `src/Transform/Globals`.

### 3. Typechecking
Typed Lua Core Typechecker consists of few kinds of rules:
* Subtyping rules
* Typing rules:
    * Statements typing rules
    * Expressions typing rules

#### Subtyping rules
Subtyping rules are implemented in file `src/Typechecker/Subtype.hs`.
They can be easily extended. In order to to this you just need to edit or add new implementation of some pattern in method `<?`.

During GSOC 2016 I implemented subtyping rules for:
* literal types
    * literal string
    * literal float
    * literal booleans
    * literal integer
* basic types
    * integer
    * string
    * number
    * bool
* nil values
* dynamic any
* `value` type
* self type
* unions
* functions
* tuples
* varargs
* tuple unions
* tables
* table fields
* recursion
    * amber rule
    * assumption
    * left-right unfolding
* expression types
    * projection types
    * filters
    * tuples of expression types

#### Typing rules
Both statements and expressions typing rules are implemented in file `src/Typechecker/Type.hs`
##### Statements typing rules
Rules can be edited/extended by adding entries to function `tStmt`.
Statement typing rules implemented during GSOC 2016:
* skip
* assignment
* typed/untyped local declaration
* recursive declaration
* method declaration
* while & if
* return statement
* void function and method call

##### Expressions typing rules
Rules can be edited/extended by adding entries to function `getTypeExp`.

Expression typechecking rules I implemented:
* literals
* variable type reading
* table index reading
* type coercions
* function definitions
* table constructors
* fields declaration
* binary operators:
    * relational
    * arithmetical
* unary operators
* function and method calls
* variable writing
* index writing
* table refinements
* expression list
* varargs
* self
* nil
* metatables
* recursion

## Examples
Directory `examples/` contains Typed Lua Core source code which is used by test suite to perform typechecking. Examples are structured in several categories:
* Simple examples
* Statements
* Tables
* Object oriented programming
* Recursion
* Metatables

## Installation
* Download & install [stack](https://docs.haskellstack.org/en/stable/README/)
* `stack setup` to install proper version of ghc
* `stack init` to create stack project files
* `stack build` to compile project

Generated library can be found in`.stack-work/install/x86_64-linux/lts-5.4/7.10.3/bin/coreTL`.
Generated binary should be run with one arg - path to file you want to parse and typecheck.
  
## Running test suite
Tests are divided into following groups:
* Parser `test/Test/Parser.hs`
* Typechecker
    * Subtyping `test/Test/Typechecker/Subtyping.hs`
    * Typechecking `test/Test/Typechecker/Typechecker.hs`  

Test suite can be executed with command `stack test`.

# TODO
Error information both for parser and typechecker is not good enough - it should contain information of error column and line. For now typechecker logs just errors like `"x is not subtype of y"` or `"table x does not contains y of type z"`, however, without some global information where you should look for error. Also sometimes parser instead of throwing error just returns empty program or gives too general information.