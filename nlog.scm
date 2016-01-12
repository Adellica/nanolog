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

;; timestamps will be added when `create-message` is run.
(define msgs (map create-message (texts)))

(if (pair? msgs)
    (for-each send-log msgs)
    (port-for-each (lambda (line) (send-log (create-message line))) read-line))
