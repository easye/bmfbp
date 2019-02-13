:- initialization(main).
:- include('head').

main :-
    readFB(user_input),
    forall(eltype(ParentID, box), check_has_port(ParentID)),
    writeFB,
    halt.

check_has_port(ParentID):-
    parent(_,ParentID),!.

check_has_port(ParentID):-
    nle,nle,we('parent '),we(ParentID),wen(' has no port'),nle,nle.

:- include('tail').
