:- initialization(main).
:- include('head').

main :-
    readFB(user_input),
    forall(eltype(PortID, port), check_has_index(PortID)),
    writeFB,
    halt.

check_has_index(PortID):-
    portIndex(PortID,_),!.

check_has_index(PortID):-
    nle,nle,we('port '),we(PortID),wen(' has no index'),nle,nle.

:- include('tail').
