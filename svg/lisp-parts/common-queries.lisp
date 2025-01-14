(in-package :arrowgram)

(paip::<- (arrowgram::point-completely-inside-bounding-box ?id1 ?id2)
    (bounding_box_left ?id1 ?L1)
    (bounding_box_top ?id1 ?T1)
    (lisp ? (format *error-output* "~&id1/~A/ left/~A/ top/~A/~%" ?id1 ?L1 ?T1))
    
    (bounding_box_left ?id2 ?L2)
    (bounding_box_top ?id2 ?T2)
    (bounding_box_right ?id2 ?R2)
    (bounding_box_bottom ?id2 ?B2)
    (lisp ? (format *error-output* "~&id2/~A/ left/~A/ top/~A/ right/~A/ bottom/~A/~%" ?id2 ?L2 ?T2 ?R2 ?B2))

    (>= ?L1 ?L2)
    (>= ?T1 ?T2)
    (>= ?R2 ?L1)
    (>= ?B2 ?T1))


(paip::<- (arrowgram::center-completely-inside-bounding-box ?ID1 ?ID2)
    (bounding_box_left ?ID1 ?L1)
    (bounding_box_top ?ID1 ?T1)
    (bounding_box_right ?ID1 ?R1)
    (bounding_box_bottom ?ID1 ?B1)
    (is ?Cx (+ ?L1 (- ?R1 ?L1)))
    (is ?Cy (+ ?T1 (- ?B1 ?T1)))
    (bounding_box_left ?ID2 ?L2)
    (bounding_box_top ?ID2 ?T2)
    (bounding_box_right ?ID2 ?R2)
    (bounding_box_bottom ?ID2 ?B2)
    (>= ?Cx ?L2)
    (=< ?Cx ?R2)
    (>= ?Cy ?T2)
    (=< ?Cy ?B2))
