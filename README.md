# Synopsis

    :- use_module(library(mavis)).

    %% even(+X:integer) is semidet.
    even(X) :-
        0 is X mod 2.

# Description

The =mavis= module (because she helps with typing ;-) allows one to
use optional type declarations in Prolog code. During *development*,
these declarations throw informative exceptions when values don't match
types.  A typical development environment converts this into a helpful
stack track which assists in locating the error.

In *production*, the declarations are completely removed by macros
and do nothing.  Production time is defined as any time when optimization is enabled:
`current_prolog_flag(optimise, true)`.

Type declarations can be give manually by calling the/2.  `mavis` also inserts
type declarations for you based on your PlDoc structured comments.  For
example, during development, the definition of `even` above becomes

    even(A) :-
        the(integer, A),
        0 is A mod 2.

The library also takes into account groundedness and determinsm as
specified in the mode line given to PlDoc. Currently the library recognises

    `erroneous`, `failure`,`semidet`,`det`,`multi`,`nondet`

The different determinism qualifiers are interpreted as follows:

* `failure`: 0 solutions
* `semidet`: 0 or 1 solution
* `det`: 1 solution
* `multi`: more than one solution
* `nondet`: Any number of solutions including 0

The groundedness currently must be one of:

    `++`,`+`,`?`,`--`,`-`,`:`,`@`,`!`

These are interpreted as follows:

* `++` means *completely* ground on entry.
* `+` means ground in a way compatible with type declaration. For `any`,
      this provides no checkable information.
* `?` means either ground, unground or mixed. If it is not a variable, we will demote the determinism as follows:
    - `det` => `semidet`
    - `multi` => `nondet`
* `--` means variable input, and type compatible output.
* `-` means an output parameter. The output should be compatible with the type. If it is not a variable, we will demote the determinism as follows:
    - `det` => `semidet`
    - `multi` => `nondet`
* `:` means a goal. Currently no checking is done.
* `@` means not further bound than on input. Currently no checking is done.
* `!` means side-effectable variable. Currently no checking is done.

"Compatibility" means that running the double-negated type over the
variable is successful, i.e. the input structure which is defined does
not contradict the type. 

## Why?

We love dynamic types. That's one reason we love Prolog. But
sometimes it is useful to distinguish between a failure, and an
incorrect utlisation of the calling contract. Types can:

  * offer documentation to those reading our code
  * help find errors during development
  * structure our thinking during development
  * provide data for static analysis tools

# Defining new types

Mavis types are defined using error:has_type/2. We might define an
`even_integer` type with

    error:has_type(even_integer, X) :-
        0 is X mod 2.

We can use the definition manually:

    frobnify(A, B) :-
        the(integer, A),
        the(even_integer, B),
        B is 2*A.

or simply add it to our PlDoc comments:

    %% frobnify(+A:integer, -B:even_integer)
    frobnify(A, B) :-
        B is 2*A.

We can declare types for bound variables, like `A`, and
not-yet-bound variables, like `B`. The type constraints are implemented
with when/2 so they apply as soon as a variable is ground.

To disable type checking in production, start Prolog with the
`-O` command line argument. A macro eliminates calls to the/2 so they
have no runtime overhead.

# Changes in this Version

  * Fix packaging error
  * Add determinism checking
  * Add groundedness checking

# TODO

There should be a less ad-hoc method of mode selection. It would also
be useful to extend the groundedness criteria 

In future versions we hope to incorporate a gradual typing discipline
using abstract interpretation. This could potentially find type,
groundedness and determinacy errors before we have run the
program. Ultimately it may also provide performance improvements.

It would also be very nice to include polymorphism, however, this
requires that we have some way to select a type. As there is no
principle typing, this is potentially a (very interesting) can of
worms.

Also of some interest would be dependent type checking, which at least
in the dynamic case, might be tractable.

# Issues

When using metapredicates such as maplist, goal expansion will get
confused and generate incorrect clauses unless the predicate has the
appropriate number of arguments. This can be achieved by wrapping the
call in a suitable lambda form. e.g. If p is given a modeline then:

```
maplist(p,Xs,Ys)
```

should be replaced with:

```
maplist([X,Y]>>(p(X,Y)),Xs,Ys
```

# Installation

Using SWI-Prolog 6.3.16 or later:

    $ swipl
    1 ?- pack_install(mavis).

Source code available and pull requests accepted on GitHub:
https://github.com/GavinMendelGleason/mavis

# Authors

* Michael Hendricks <michael@ndrix.org>
* Gavin Mendel-Gleason <gavin@datachemist.com>
