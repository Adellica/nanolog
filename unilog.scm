(use files spiffy intarweb uri-common srfi-18 nrepl reser persistent-hash-map posix)

(define store-root (make-parameter #f))

(define cla command-line-arguments)
(cond ((= 2 (length (cla)))
       (store-root (car (cla)))
       (server-port (string->number (cadr (cla)))))
      (else (error "usage: <storage-path> <port>")))

(define (app r)
  ;; try to make a serializeable scheme object from request (replace
  ;; records with lists etc)
  (let ((reqobj `((ts . ,(current-seconds))
                  (remote . ,(remote-address))
                  ,@(map->alist (map-update-in r '(uri) uri->list)))))

    (define filename (conc (time->string (seconds->utc-time) "%Y-%m") ".scm"))
    (define (show x) (pp x) (flush-output))

    (define (append obj)
      (let ((port (open-output-file* (file-open filename (+ open/write open/append open/creat)))))
        (pp obj port)
        (close-output-port port)))

    (append reqobj)
    (with-output-to-port (current-error-port) show)
    (response body: "{\"status\" : \"ok\"}\n")))

(define handler (wrap-errors app))

(define nrepl-thread  (thread-start! (lambda () (nrepl (+ 1 (server-port))))))
(define server-thread (thread-start! (lambda () (reser-start (lambda (r) (handler r))))))


(thread-join! server-thread)
