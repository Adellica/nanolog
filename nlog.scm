(include "libnlog.scm")

(define msgs (map create-message (command-line-arguments)))

(if (pair? msgs)
    (for-each send-log-http msgs)
    (port-for-each (lambda (line) (send-log-http (create-message line))) read-line))
