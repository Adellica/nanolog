(include "libnlog.scm")

(if (member "-d" (command-line-arguments))
    (debug? #t))

(define (texts)
  (filter (lambda (x) (not (string-prefix? "-" x)))
          (command-line-arguments)))

(define msgs (map create-message (texts)))

(if (pair? msgs)
    (for-each send-log-http msgs)
    (port-for-each (lambda (line) (send-log-http (create-message line))) read-line))
