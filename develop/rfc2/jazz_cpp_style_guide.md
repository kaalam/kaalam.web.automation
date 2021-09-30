# Jazz C++ Style Guide

We fork Google C++ style guide with some divergent rules, detailed in this document. For anything else, use Google's style guide as reference. Reference https://google.github.io/styleguide/cppguide.html


### SWDWGAD principle

"Since when don't we give a damn?" (SWDWGAD) is a sensation one may have looking at some code bases. Well, in Jazz we do give a damn, we expect the code to be running 30 years from now. We understand some coders get mad when someone else fixes formatting or spelling issues. Some very talented people don't need order, others do. We want to include everyone here. So please, have a thick skin when your code gets fixed on what you consider "silly" issues, and above all: never make it personal. Also, ugly code acts like an implicit permission to do ugly things with it. That only gets worse with time.


### Consistency first

These rules do not apply to files that are completely imported from other projects or contributions of complete files (especially, LMDB and Catch2!). In those cases, consistency with pre-existing formatting prevails.


### Line length, tab size and encoding

Rather than using Google's 80 character with 4 exceptions rule, we use column 150(*) as a limit, no exceptions. Tabs are used, tab space is 4, line feed is POSIX \\n and trailing space is removed.

(*) Note that column 150 is not exactly the same as 150 characters per line as tabs count as the number of spaces they replace.


### English only, EN_US, UTF8

English only, for everything: comments, UI, naming, ... Avoid the use of non ASCII chars when possible. They are acceptable in remarks or string constants when necessary. i18n applies to front-end UIs, NOT the server, NOT the framework, NOT the Bebop language, NOT the documentation and NOT the APIs.


### Use of space

Never before a comma, always after a comma except when another comma follows. Always before and after arithmetic and logic operators, except arithmetic * and / and only before pointer operators. Never immediately inside parentheses except for alignment. Always outside parameters near primitives if, while, for, etc. In function calls and definitions, space is just for alignment.


### Use of vertical space

Two blank lines before a method's documentation. No space between the doc and the body or at the beginning or the end. One line space each time you separate blocks. There is no definition of "block", just similar things make the same block for readability.


### Use of vertical alignment

Use more than one consecutive spaces (besides indenting) to improve readability by vertical alignment when two (or more) consecutive lines share a structure and alignment makes their differences evident. We favor readability and error spotting over higher future editing work in case of modification.


### Comments

Think doxy! You are creating a doxygen page, never forget that. Check doxygen doc when in doubt.


### TODOs

The line with TODOs must match the regex "^//TODO:(.*)$" the bracket should catch something displayable 'as is' (without assuming any character escaping logic) as a title. Avoid "not implemented" as a TODO, it should be notes about known limitations of the code.


### Exceptions

Even against the opinion of Google and our own previous position, we use exceptions in Jazz, but limited to Bebop. Bebop is a language and a very simple one. Forcing error checking in Bebop through conditionals would make Bebop a hell. Of course, we could simulate exceptions for predictable errors. But, we are convinced that we would regret the decision to do so when unpredictable errors show up. The cleanest way to provide exceptions to Bebop is rooting them in C++ exceptions in Jazz.

The only acceptable exception type is **int**. The only acceptable values are:

  - Those used by c++ stdlib
  - Some constants declared in jazz.h named EXCEPTION_xxx that do not collide with the values in stdlib.


### Templates

Never use templates if they don't make expressions cleaner. Templates in stdlib containers are amazing, there is not much need of them in Jazz.


### Macros

Jazz 0.1.+ had the "magical" ALLOC(), REALLOC() and FREE() macros. They co-exist in Jazz 0.2.+ until the original code is fully replaced by the new structure. They are banned in Jazz 0.3.1 and above. **Just to clarify: Preprocessor constants are NOT macros** (macros have arguments) and are used all over the source code. There is no intention to change that, this is considered excellent practice in C/C++. Preprocessor constants are not typed, so type should always be obvious, just keep it simple.


### Operator Overloading

Don't.


## Bear in mind

All this is literally taken from Google's style guide, we just repeat it to make sure it is not ignored.

  - \#define guards are imperative and based on the full path in a project's source tree.
  - Use namespaces. Namespace names are all lower-case. Namespaces do not add an extra level of indentation.
  - Place a function's variables in the narrowest scope possible, and initialize variables in the declaration.
  - Specify noexcept when it is useful and correct. (Typically, for the server.)
  - Use nullptr instead of NULL.
  - Prefer sizeof(var name) to sizeof(type).
  - Avoid abbreviation.
  - Filenames should be all lowercase and can include underscores.
  - Type names start with a capital letter and have a capital letter for each new word, with no underscores.
  - The names of variables (including function parameters) and data members are all lowercase, with underscores between words.
  - Regular functions have mixed case; accessors and mutators may be named like variables.
  - No spaces around period or arrow. Pointer operators do not have trailing spaces: *a, &b, c.d, e->f
  - Do not needlessly surround the return expression with parentheses.
  - The hash mark that starts a preprocessor directive should always be at the beginning of the line.
  - No spaces inside the angle brackets.
