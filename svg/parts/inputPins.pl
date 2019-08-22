:- initialization(main).
:- include('head').

main :-
    readFB(user_input),
    condSinkRect
    writeFB,
    halt.

condSinkRect :-
    forall(rect(RectID),makeInputPins(RectID)),
    !.
condSinkRect :- true.

makeInputPins(RectID) :-
    parent(RectID,PortID),
    port(PortID),
    sink(PortID),
    asserta(inputPin(PortID)).

:- include('tail').