(use spiffy intarweb uri-common srfi-18 nrepl reser persistent-hash-map)

(define cla command-line-arguments)
(if (= 1 (length (cla)))
    (server-port (string->number (car (cla))))
    (error "usage: <port>"))

(define (app r)
  ;; try to make a serializeable scheme object from request (replace
  ;; records with lists etc)
  (let ((reqobj `((ts . ,(current-seconds))
                  (remote . ,(remote-address))
                  ,@(map->alist (map-update-in r '(uri) uri->list)))))
    (define (show)
      (write reqobj) (display "\n") (flush-output))

    (with-output-to-port (current-output-port) show)
    (with-output-to-port (current-error-port) show)
    (response body: "ok\n")))

(define handler (wrap-errors app))

(define nrepl-thread  (thread-start! (lambda () (nrepl (+ 1 (server-port))))))
(define server-thread (thread-start! (lambda () (reser-start (lambda (r) (handler r))))))


(thread-join! server-thread)
