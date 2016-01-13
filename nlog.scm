(include "libnlog.scm")

(define send-log send-log-nanomsg)

(if (member "-d" (command-line-arguments))
    (debug? #t))

(if (member "-c" (command-line-arguments))
    (set! send-log send-log-http))

(if (member "-h" (command-line-arguments))
    (begin (print "usage: [-d / debug] [-c / no daemon] [msg1 ...]\n"
                  "without msg arguments, sends line-by-line from stdin")
           (exit 0)))

(define (texts)
  (filter (lambda (x) (not (string-prefix? "-" x)))
          (command-line-arguments)))

;; (cla->msg '("text" "field=1" "more text" "field=2"))
(define (cla->msg args)

  (define (alist-vector-append alst key value)

    (define (vector-append v1 v2)
      (list->vector (append (vector->list v1) (vector->list v2))))

    (alist-update key
                  (vector-append (or (alist-ref key alst) (vector)) (vector value))
                  alst))
  (fold (lambda (x s)
          (let ((components (string-split x "=")))
            (if (eq? 2 (length components))
                (alist-vector-append s
                                     (string->symbol (car components))
                                     (cadr components))
                (alist-vector-append s 'body x))))
        '()
        args))

(send-log (create-message (cla->msg (texts))))
