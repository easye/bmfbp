:- initialization(main).
:- include('head').

main :-
    readFB(user_input), 
    condMeta,
    writeFB,
    halt.

condMeta :-
    forall(metadata(MID,_),createMetaDataRect(MID)).

condMeta :-
    true.

createMetaDataRect(MID) :-
    metadata(MID,TextID),
    rect(BoxID),
    metadataCompletelyInsideBoundingBox(TextID,BoxID),
    asserta(used(TextID)),
    asserta(roundedrect(BoxID)),
    component(Main),
    asserta(parent(Main,BoxID)),
    asserta(log(BoxID,box_is_meta_data)),
    retract(rect(BoxID)).

createMetaDataRect(TextID) :-
    wen(' '),we('createMetaDataRect failed '),wen(TextID).

metadataCompletelyInsideBoundingBox(TextID,BoxID) :-
    centerCompletelyInsideBoundingBox(TextID,BoxID).

:- include('tail').
