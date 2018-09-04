:- use_module(library(mavis)).
:- use_module(library(tap)).

/** 
 * even(+X:integer) is semidet.
 */
even(X) :-
    0 is X mod 2.

/** 
 * is_graph(+Graph) is semidet.
 * 
 * True if Graph is a well formed graph
 */
is_graph(graph(Instance,Inference,Schema)) :-
    atom(Instance),
    atom(Inference),
    atom(Schema).

error:has_type(graph, X) :-
    is_graph(X).

:- multifile quickcheck:arbitrary/2.
quickcheck:arbitrary(graph, graph(A,B,C)) :-
    arbitrary(atom, A),
    arbitrary(atom, B),
    arbitrary(atom, C).

/** 
 * graph_instance(+Graph:graph, ?GraphName:atom) is det.
 */
graph_instance(graph(Instance,_,_),Instance).

frobnify(A,B) :-
    the(integer,A), A=B.

brofnify(A,B) :-
    the(string,A),A=B.

/** 
 * first_string(+X:list(string), ?Y:string) is det.
 */
first_string([X|_],X).

/** 
 * back_and_forth(+X,-Y) is det.
 * back_and_forth(-X,+Y) is semidet.
 */ 
back_and_forth(X,Y) :-
    Y=[1|X].

/** 
 * something(+X:integer,-Y:integer) is det.
 */ 
something(X,Y) :-
    (   even(X)
    ->  Y is X * 2
    ;   Y is X * 3
    ).

/** 
 * dependent_type(+X:integer,+Y:([A]>>(A<X)), -Z) is det.
 */ 
dependent_type(X,Y,Z) :-
    Z is X * Y.


/** 
 * elt(+X,List) is nondet.
 * elt(-X,+List) is nondet.
 */
elt(X,L) :-
    member(X,L).

/** 
 * unit(+X,-Y:list) is det.
 */ 
unit(X, Y) :-
    Y = [X].

/** 
 * multi(-X) is multi.
 * multi(+X) is semidet.
 */ 
multi(X) :- member(X,[1,2,3,1,2,3]).
multi(X) :- X = 4.


/** 
 * not_multi(+X) is multi.
 * not_multi(-X) is multi.
 */
not_multi(X) :- member(X,[1,2,1,2,3]).

/** 
 * test_demotion(+X:integer,-Y:integer) is det
 */
test_demotion(X,Y) :-
    Y is X-1.

/** 
 * test_demotionless(+X:integer,--Y:integer) is det
 */
test_demotionless(X,Y) :-
    Y is X-1.

/** 
 * ignore something(+X) is det.  
 * 
 */ 
something(X) :-
    X = 1.

testing :-
    unit(1,_),
    something(2,_),
    back_and_forth([1,2,3],_),
    first_string(["asdf","fdsa"],_),
    test_demotion(1,_),
    (   test_demotion(1,2)
    ;   true).




