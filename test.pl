:- use_module(library(mavis)).
:- use_module(library(dcg/basics), [string//1]).

%% stuff(+Greeting:integer, +X:atom) is semidet.
%
%  Do stuff with Greeting and X.  This is a longer comment to
%  make sure I understand how the comments look after PlDoc
%  has parsed them internally.
stuff(Greeting, Name) :-
    format('~w, ~w~n', [Greeting,Name]).

%%  grammar(-Name:codes)//
grammar(Name) -->
    "hello ",
    string(Name).

%%  from_name(Codes, Atom, Extra:atom)
from_name(Codes, Atom, Extra) :-
    Extra = extra,
    atom_codes(Atom, Codes).

%% lazy(Foo)
lazy(_).

/** 
 * elt(+X,List) is nondet.
 * elt(-X,+List) is nondet.
 * 
 * Two modelines with no typing information
 */
elt(X,L) :-
    member(X,L).

/** 
 * elt_det(+X:integer,+List:list(integer)) is det.
 * 
 * Two modelines with no typing information
 */
elt_det(X,L) :-
    (   member(X,L)
    ->  true
    ;   false).

