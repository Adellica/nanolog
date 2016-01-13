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


(define (msg-append alst key value)

  (define (vector-append v1 v2)
    (list->vector (append (vector->list v1) (vector->list v2))))

  (alist-update key
                (let ((old (alist-ref key alst)))
                  (if old
                      (vector-append (if (vector? old) old (vector old)) (vector value))
                      value))
                alst))

;; (cla->msg '("text" "field=1" "more text" "field=2" "k=v"))
(define (cla->msg args)

  (fold (lambda (x s)
          (let ((components (string-split x "=")))
            (if (eq? 2 (length components))
                (msg-append s
                                     (string->symbol (car components))
                                     (cadr components))
                (msg-append s 'body x))))
        '()
        args))

(send-log (create-message (cla->msg (texts))))
