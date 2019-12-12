:- module(mavis, [ the/2
                 , has_intersection/2
                 , has_subtype/2
                 , known_type/1
                 , build_type_assertions/3
                 , build_determinism_assertions/2
                 , run_goal_at_mode/4
                 ]).


:- use_module(library(quickcheck)).
:- use_module(library(error)).


/** <module> Optional type declarations
Declare optional types which are checked during development time.
See pack documentation for more information.
*/

module_wants_mavis(Module) :-
    Module \= mavis,
    predicate_property(Module:the(_,_), imported_from(mavis)).

%%	the(+Type:type, ?Value) is det.
%
%	Declare that Value has the given Type.
%	Succeeds if Value is bound to a value that's compatible
%	with Type.  Throws an informative exception if Value
%	is bound to a value that's not compatible with Type.
%	If Value is not bound, the type check is delayed until
%	Value becomes ground.
%
%	When optimizations are enabled
%	(=|current_prolog_flag(optimise, true)|=) a macro removes =the=
%	entirely so that it always succeeds.
:- if(current_prolog_flag(optimise,true)).

the(_,_).  % avoid "Exported procedure mavis:the/2 is not defined"
user:goal_expansion(the(_,_), true).

build_determinism_assertions(_,_) :- fail.  
build_type_assertions(_,_,_) :- fail.  
run_goal_at_mode(_,_,_,_) :- fail.

:- else.

:- use_module(library(apply), [exclude/3]).
:- use_module(library(charsio), [read_term_from_chars/3]).
:- use_module(library(list_util), [xfy_list/3,split_at/4]).
:- use_module(library(pldoc)).
:- use_module(library(pldoc/doc_wiki), [indented_lines/3]).
:- use_module(library(when), [when/2]).
:- doc_collect(true).

% extract mode declaration from a structured comment
mode_declaration(Comment, ModeCodes) :-
    string_to_list(Comment, Codes),
    phrase(pldoc_process:structured_comment(Prefixes,_), Codes, _),
    indented_lines(Codes, Prefixes, Lines),
    pldoc_modes:mode_lines(Lines, ModeCodes, [], _).

% There may be more varieties of this that we have to handle
% see read_term/2
end_pos(Pos,End) :- 
    (   Pos=term_position(_, End, _, _, _)
    ->  true
    ;   Pos=_-End).

exhaustive_read_term(Codes,[Term|Terms]) :-
    Options = [module(pldoc_modes),
               variable_names(Vars),
               subterm_positions(Pos)],
    read_term_from_chars(Codes,Term,Options),
    end_pos(Pos,End),
    Term \= end_of_file,
    !,
    maplist(call,Vars),
    Next is End + 2, % one for 0 offset, one for '.'
    split_at(Next,Codes,_,NewCodes),
    exhaustive_read_term(NewCodes,Terms).
exhaustive_read_term(_Codes,[]).

% read all mode declarations from character codes
read_mode_declarations(ModeCodes, Modes) :-
    exhaustive_read_term(ModeCodes, Modes).

% convert mode declarations to a standard form
normalize_mode(Mode0, Args, Det) :-
    (Mode0 = is(Mode1, Det) -> true; Mode1=Mode0, Det=nondet),
    (Mode1 = //(Mode2) -> Slash='//'; Mode2=Mode1, Slash='/' ),
    _ = Slash, % avoid singleton warnings (until Slash is needed)
    Mode2 =.. [_|RawArgs],
    maplist(normalize_args, RawArgs, Args).

normalize_args(X0, arg(Mode,Name,Type)) :-
    ( var(X0) -> X1 = ?(X0:any) ; X1=X0 ),
    ( X1 =.. [Mode0,Arg] -> true; Mode0='?', Arg=X1 ),
    ( member(Mode0, [++,+,-,--,?,:,@,!]) -> Mode=Mode0; Mode='?' ),
    ( nonvar(Arg), Arg=Name:Type -> true; Name=Arg, Type=any).

the(Type, Value) :-
    when(ground(Value), error:must_be(Type, Value)).

% create a the/2 type assertion based on a variable and
% the declared mode information for that variable.
type_declaration(Var, arg(_,_,Type), the(Type, Var)).

% convert a clause head into a goal which asserts all types
% associated with that head.  Slash is '/' for a normal
% predicate and '//' for a DCG.  Pneumonic: foo/1 vs foo//1
build_type_assertions(Slash, Head, TypeGoal) :-
    % does this module want mavis type assertions?
    prolog_load_context(module, Module),
    mavis:module_wants_mavis(Module),

    % fetch this predicate's structured comment
    functor(Head, Name, Arity),
    Indicator =.. [Slash, Name, Arity],
    pldoc_process:doc_comment(Module:Indicator,_,_,Comment),

    % parse and normalize mode description
    mode_declaration(Comment, ModeText),
    %debug(mavis, "~q has modeline `~s`~n", [Module:Indicator, ModeText]),
    % Warning: Potential bug!!!
    % We assume type consistency between modes...
    %debug(mavis, "~q has modeline `~s`~n", [Module:Indicator, ModeText]),
    read_mode_declarations(ModeText, [RawMode|_]),
    debug(mavis, "~q has types from `~q`~n", [Module:Indicator, RawMode]),
    normalize_mode(RawMode, ModeArgs, _Determinism),

    Head =.. [Name|HeadArgs],
    maplist(type_declaration, HeadArgs, ModeArgs, AllTypes),
    exclude(=(the(any, _)), AllTypes, Types),
    xfy_list(',', TypeGoal, Types).

build_determinism_assertions(Goal,Wrapped) :-
    % does this module want mavis type assertions?
    prolog_load_context(module, Module),
    mavis:module_wants_mavis(Module),
    
    % fetch this predicate's structured comment
    functor(Goal, Name, Arity),
    Indicator =.. ['/', Name, Arity],

    pldoc_process:doc_comment(Module:Indicator,_,_,Comment),
    
    % parse and normalize mode description
    mode_declaration(Comment, ModeText),
    read_mode_declarations(ModeText, RawModes),
    % fail if there are no mode declarations (to leave the goal unchanged)
    \+ RawModes = [],
    maplist([RawMode,mode(ModeArgs,Determinism)]>>normalize_mode(RawMode, ModeArgs, Determinism),
            RawModes,Modes),
    %%debug(mavis, "~q has modeline `~s`~n", [Module:Indicator, Modes]),        
    % We should really check for mode consistency here.
    
    Goal =.. [Name|Args],
    Wrapped = mavis:run_goal_at_mode(Module,Name,Modes,Args).

% pre_check_groundedness(arg(Groundedness,_,Type),Arg,Demote) is det.
% Promote holds a 0 or 1 depending on whether we should demote
% in the event of increased nondeterminism.
pre_check_groundedness(arg('++',_,Type),Arg,0) :-
    ground(Arg),
    (   \+ error:has_type(Type,Arg)
    ->  throw(domain_error(Type,Arg))
    ;   true).
pre_check_groundedness(arg('+',_,Type),Arg,0) :-
    % This will be type checked too late due to suspension
    % unless we do it now.
    % (negation avoids bindings)
    \+ var(Arg),
    (   \+ error:has_type(Type,Arg)
    ->  throw(domain_error(Type,Arg))
    ;   true).
pre_check_groundedness(arg('-',_,_),Arg,Demote) :-
    (   var(Arg)
    ->  Demote = 0
    ;   Demote = 1).
pre_check_groundedness(arg('--',_,_),Arg,0) :-
    var(Arg).
pre_check_groundedness(arg('?',_,_),Arg,Demote) :-
    (   var(Arg)
    ->  Demote = 0
    ;   Demote = 1).
pre_check_groundedness(arg(':',_,_),_Arg,0).
pre_check_groundedness(arg('!',_,_),_Arg,0).
pre_check_groundedness(arg('@',_,_),_Arg,0).

post_check_groundedness(arg('-',_,Type),Arg) :-
    !,
    (   \+ error:has_type(Type,Arg)
    ->  throw(domain_error(Type,Arg))
    ;   true).
post_check_groundedness(arg('--',_,Type),Arg) :-
    !,
    (   \+ error:has_type(Type,Arg)
    ->  throw(domain_error(Type,Arg))
    ;   true).
post_check_groundedness(arg(_,_,_),_Arg).

demote(det,1,semidet).
demote(multi,1,nondet).
demote(fail,1,fail).
demote(semidet,1,semidet).
demote(nondet,1,nondet).
demote(erroneous,1,erroneous).
demote(X,0,X).

choose_mode([mode(Mode,Determinism)|_Modes],Args,_Module,_Name,
            mode(Mode,DeterminismPrime)) :-
    maplist(pre_check_groundedness,Mode,Args,DemotionVotes),
    foldl([X,Y,R]>>(R is X \/ Y),DemotionVotes,0,Demote),
    demote(Determinism,Demote,DeterminismPrime),
    !.
choose_mode([_|Modes],Args,Module,Name,Mode) :-
    choose_mode(Modes,Args,Module,Name,Mode).
        
run_goal_at_mode(Module,Name,Modes,Args) :-
    Goal =.. [Name|Args],
    (   choose_mode(Modes,Args,Module,Name,mode(Mode,Determinism))
    ->  true
    ;   throw(mode_error(Modes,apply(Module:Name,Args)))),
    run_goal_with_determinism(Determinism,Module,Goal),
    (   maplist(post_check_groundedness,Mode,Args)
    ->  true
    ;   throw(mode_error(Modes,apply(Module:Name,Args)))).

run_goal_with_determinism(erroneous,Module,Goal) :-
    !,
    throw(determinism_error(Module:Goal,erroneous)).
run_goal_with_determinism(failure,Module,Goal) :-
    !,
    call(Module:Goal),
    throw(determinism_error(Module:Goal,failure)).
run_goal_with_determinism(det,Module,Goal) :-
    !,
    (   call_cleanup(Module:Goal, Det=true),
        (   Det == true
        ->  true
        ;   throw(determinism_error(Module:Goal, det))
        )
    ->  true
    ;   throw(determinism_error(Module:Goal, det))
    ).
run_goal_with_determinism(semidet,Module,Goal) :-
    !,
    (   call_cleanup(Module:Goal, Det=true),
        (   Det == true
        ->  true
        ;   throw(determinism_error(Module:Goal, semidet))
        )
    ->  true
    ;   fail
    ).
run_goal_with_determinism(multi,Module,Goal) :-
    !,
    (   call(Module:Goal)
    *-> true
    ;   throw(determinism_error(Module:Goal,multi))
    ).
run_goal_with_determinism(_,Module,Goal) :-
    call(Module:Goal).

bodyless_predicate(Term) :-
    \+ Term = (:-_),
    \+ Term = (_:-_),
    \+ Term = (_-->_),
    \+ Term = end_of_file.

user:term_expansion((Head:-Body), (Head:-TypeGoal,Body)) :-
    Slash = '/',
    build_type_assertions(Slash, Head, TypeGoal).

user:term_expansion(Head,(Head:-TypeGoal)) :-
    bodyless_predicate(Head),
    Slash = '/', 
    build_type_assertions(Slash, Head, TypeGoal).

user:term_expansion((Head-->Body), (Head-->{TypeGoal},Body)) :-
    Slash = '//',
    build_type_assertions(Slash, Head, TypeGoal).

% TODO:
% We need to check mode assignments and discover if they are
% A) disjoint
%    a) if they are disjoint we need to check groundedness
%       1) Add dynamic check groudedness.
%       2) Do a separate determinism check per groudedness.
%    b) Throw runtime error if not disjoint.
%
% TODO:
% Later it would be nice if we had skeletons (ala mercury).
user:goal_expansion(Goal,Wrapped) :-
    build_determinism_assertions(Goal,Wrapped),
    debug(mavis,'~q => ~q~n', [Goal,Wrapped]).

:- multifile prolog:message//1.
prolog:message(determinism_error(Goal, Det)) -->
    [ 'The Goal ~q is not of determinism ~q'-[Goal,Det]].
prolog:message(domain_error(Domain, Term)) -->
    [ 'The term ~q is not in the domain ~q'-[Term,Domain]].
prolog:message(mode_error(Mode, Term)) -->
    [ 'The term ~q does not have a valid mode in ~q'-[Term,Mode]].

:- endif.


% below here, code that loads all the time

%% type_subtype(?Type, ?Subtype)
%
%  Multifile predicate for declaring that a Type has a Subtype. It
%  should only be necessary to add clauses to this predicate if
%  has_subtype/2 has trouble deriving this information based on
%  your definition of `quickcheck:arbitrary/2`.
:- dynamic type_subtype/2.
:- multifile type_subtype/2.

%% has_subtype(+Type, +Subtype) is semidet.
%
%  True if all values of Subtype are also values of Type. This can be
%  used to determine whether arguments of one type can be passed to a
%  predicate which demands arguments of another type.
%
%  This predicate performs probabilistic subtype detection by leveraging
%  your definitions for `error:has_type/2` and `quickcheck:arbitrary/2`.
%  If this predicate is not detecting your types correctly, either
%  improve your quickcheck:arbitrary/2 definition or add clauses to
%  the multifile predicate type_subtype/2.
has_subtype(Type, Subtype) :-
    ( var(Type); var(Subtype) ),
    !,
    fail.
has_subtype(Type, Subtype) :-
    type_subtype(Type, Subtype),
    !.
has_subtype(Type, Subtype) :-
    error:must_be(nonvar, Type),
    error:must_be(arbitrary_type, Subtype),
    \+ counter_example(Type, Subtype, _),
    assert(type_subtype(Type, Subtype)).

% find a value (Example) which belongs to Subtype but not
% to Type.  This demonstrates that Subtype is not a strict
% subset of Type.
counter_example(Type, Subtype, Example) :-
    between(1,100,_),
    quickcheck:arbitrary(Subtype, Example),
    \+ error:is_of_type(Type, Example),
    !.


%% type_intersection(?Type, ?IntersectionType)
%
%  Multifile predicate for declaring that Type has an IntersectionType.
%  See type_subtype/2 for further details.
:- dynamic type_intersection/2.
:- multifile type_intersection/2.


%% has_intersection(Type, IntersectionType) is semidet
%
%  True if some value of IntersectionType is also of Type. See
%  has_subtype/2 for further details.
has_intersection(Type, Intersection) :-
    ( var(Type); var(Intersection) ),
    !,
    fail.
has_intersection(Type, Intersection) :-
    type_intersection(Type, Intersection),
    !.
has_intersection(Type, Subtype) :-
    error:must_be(nonvar, Type),
    error:must_be(arbitrary_type, Subtype),
    shared_value(Type, Subtype, _),
    assert(type_intersection(Type, Subtype)).

% Find a value shared by both Type and Subtype
shared_value(Type, Subtype, Value) :-
    between(1,100,_),
    quickcheck:arbitrary(Subtype, Value),
    error:is_of_type(Type, Value),
    !.


%% known_type(?Type:type) is semidet.
%
%  True if Type is a type known to error:has_type/2. Iterates
%  all known types on backtracking. Be aware that some types are
%  polymorphic (like `list(T)`) so Type may be a non-ground term.
%
%  As a convenience, the type named `type` describes the set of all
%  values for which `known_type/1` is true.
known_type(Type) :-
    dif(Type, impossible),  % library(error) implementation detail
    clause(error:has_type(Type, _), _Body, _Ref).


:- multifile error:has_type/2.
error:has_type(type, T) :-
    known_type(T).
