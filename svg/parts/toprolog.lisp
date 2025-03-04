(defun all-digits-p (str)
  (let ((i (1- (length str))))
    (loop
       (case (schar str i)
	 ((#\0 #\1 #\2 #\3 #\4 #\5 #\5 #\6 #\7 #\8 #\9)
	  (when (< (decf i) 0)
	    (return t)))	  
	 (otherwise
	  (return-from all-digits-p nil)))))
  t)

(defun next-id ()
  (gensym "id"))

(defparameter *p* 20)  ;; port width and height - play with this if you get "no parent for box" errors

(defun contains-junk-p (s)
  (notevery #'(lambda (c) (or 
			   (alphanumericp c)
			   (char= c #\_)))
	    s))

(defparameter *metadata-already-seen* nil)

(defun to-prolog (list strm)
  (unless (listp list)
    (die (format nil "to-prolog list=/~a/" list)))
  (if (listp (car list))

      (progn
        (to-prolog (car list) strm)
        (mapc #'(lambda (x) (to-prolog x strm)) (rest list)))

    (let ((new-id (next-id)))
      ;(format *error-output* "to-prolog list: ~S~%" list)
      (case (car list)

	(nothing nil)

	(component
	 (format strm "component('~A').~%" (second list)))

        (line
	 (let ((begin-id (next-id))
	       (end-id (next-id))
	       (edge-id (next-id)))
           (destructuring-bind (line-sym begin end)
               list
             (declare (ignore line-sym))
             (destructuring-bind (begin-sym x1 y1)
		 begin
               (declare (ignore begin-sym))
               (destructuring-bind (end-sym x2 y2)
                   end
		 (declare (ignore end-sym))
		 (format strm "line(~A).~%"	new-id)

		 (format strm "edge(~A).~%" edge-id)
		 (format strm "source(~A,~A).~%" edge-id begin-id)
		 (format strm "eltype(~A,port).~%" begin-id)
		 (format strm "port(~A).~%" begin-id)
		 (format strm "bounding_box_left(~A,~A).~%" begin-id (- x1 *p*))
		 (format strm "bounding_box_top(~A,~A).~%" begin-id (- y1 *p*))
		 (format strm "bounding_box_right(~A,~A).~%" begin-id (+ x1 *p*))
		 (format strm "bounding_box_bottom(~A,~A).~%" begin-id (+ y1 *p*))
		 
		 (format strm "sink(~A,~A).~%" edge-id end-id)
		 (format strm "eltype(~A,port).~%" end-id)
		 (format strm "port(~A).~%" end-id)
		 (format strm "bounding_box_left(~A,~A).~%" end-id (- x2 *p*))
		 (format strm "bounding_box_top(~A,~A).~%" end-id (- y2 *p*))
		 (format strm "bounding_box_right(~A,~A).~%" end-id (+ x2 *p*))
		 (format strm "bounding_box_bottom(~A,~A).~%" end-id (+ y2 *p*)))))))
        
        (rect
	 ;; rect is given as {top-left, width, height}
         (destructuring-bind (rect-sym x1 y1 w h)
             list
           (declare (ignore rect-sym))
           (format strm "rect(~A).~%eltype(~A,box).~%~%geometry_left_x(~A,~A).~%geometry_top_y(~A,~A).~%geometry_w(~A,~A).~%geometry_h(~A,~A).~%"
                   new-id new-id new-id x1 new-id y1 new-id w new-id h)))

        (metadata
	 ;; same as rect except with extra string
         (destructuring-bind (sym str x y w h)
             list
           (declare (ignore sym))
	   (flet ((do-meta ()
		    (let ((strid (string-to-map str))
			  (rr-id (next-id))
			  (text-id (next-id)))
		      (format strm "metadata(~A,~A).~%" new-id text-id)
		      (format strm "eltype(~A,metadata).~%" new-id)
		      (format strm "used(~A).~%" text-id)
		      
		      ;; rounded rect
		      (let ((fake-w (+ 10 w))
			    (fake-h (+ 10 h))
			    (fake-left-x (- x 10))
			    (fake-top-y (- y 10)))
			;; the actual coords of the rounded rect might come from the first pass, but we fake them here for
			;; ease of implementation of the POC
			(format strm "roundedrect(~A).~%" rr-id)
			(format strm "eltype(~A,roundedrect).~%" rr-id)
			(format strm "geometry_left_x(~A,~A).~%" rr-id fake-left-x)
			(format strm "geometry_top_y(~A,~A).~%" rr-id fake-top-y)
			(format strm "geometry_w(~A,~A).~%" rr-id fake-w)
			(format strm "geometry_h(~A,~A).~%" rr-id fake-h))
		      
		      ;; text
		      (format strm "text(~A,~A).~%" text-id strid)
		      (format strm "geometry_center_x(~A,~A).~%" text-id (+ x (/ w 2)))
		      (format strm "geometry_top_y(~A,~A).~%" text-id y)
		      (format strm "geometry_w(~A,~A).~%" text-id w)
		      (format strm "geometry_h(~A,~A).~%" text-id h))))
	     
	     (cond ((null *metadata-already-seen*)
		    (setf *metadata-already-seen* str)
		    ;(format *error-output* "doing new metadata~%")
		    (do-meta))
		   ((not (string= *metadata-already-seen* str))
		    (die "more than one different metadata"))
		   (t
		    (format *error-output* "~%skipping duplicate metadata~%")
					; skip
		    )))))


	(speechbubble
         (destructuring-bind (sym p1 p2 p3 p4 p5 p6 p7 zed)
             list
           (declare (ignore sym zed p4 p5 p6 p7))
	   (let ((x1 (second p1))
		 (y1 (third p1)))
	     (let ((w (- (second p2) x1))
		   (h (- (third p3) y1)))
           (format strm "speechbubble(~A).~%eltype(~A,speechbubble).~%~%geometry_left_x(~A,~A).~%geometry_top_y(~A,~A).~%geometry_w(~A,~A).~%geometry_h(~A,~A).~%"
                   new-id new-id new-id x1 new-id y1 new-id w new-id h)))))

        (text
	 ;; text is given as {center-x, top-y, width/2, height}
         (destructuring-bind (text-sym str x1 y1 w h)
             list
           (declare (ignore text-sym))
	   (let ((strid (if (all-digits-p str) 
			    str 
			    (string-to-map str))))
             (format strm "text(~A,~A).~%geometry_center_x(~A,~A).~%geometry_top_y(~A,~A).~%geometry_w(~A,~A).~%geometry_h(~A,~A).~%"
                     new-id strid new-id x1 new-id y1 new-id w new-id h))))

	(ellipse
         (destructuring-bind (sym x1 y1 w h)
             list
           (declare (ignore sym))
           (format strm "ellipse(~A).~%eltype(~A,ellipse).~%~%geometry_center_x(~A,~A).~%geometry_center_y(~A,~A).~%geometry_w(~A,~A).~%geometry_h(~A,~A).~%"
                   new-id new-id new-id x1 new-id y1 new-id w new-id h)))

	(dot
         (destructuring-bind (sym x1 y1 w h)
             list
           (declare (ignore sym))
           (format strm "dot(~A).~%eltype(~A,dot).~%~%geometry_center_x(~A,~A).~%geometry_top_y(~A,~A).~%geometry_w(~A,~A).~%geometry_h(~A,~A).~%"
                   new-id new-id new-id x1 new-id y1 new-id w new-id h)))


        (arrow
         (destructuring-bind (arrow-sym x1 y1)
             list
           (declare (ignore arrow-sym))
           (format strm "arrow(~A).~%arrow_x(~A,~A).~%arrow_y(~A,~A).~%"
                   new-id new-id x1 new-id y1)))

        (otherwise
         (die (format nil "bad format in toprolog /~A/" list))))))
      
  (values))
