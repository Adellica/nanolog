(use files spiffy intarweb uri-common srfi-18 nrepl reser persistent-hash-map posix)

(define store-root (make-parameter #f))

(define cla command-line-arguments)
(cond ((= 2 (length (cla)))
       (store-root (car (cla)))
       (server-port (string->number (cadr (cla)))))
      (else (error "usage: <storage-path> <port>")))

(system "ip -4 -o a") ;; give a hint on which url the server can be reached on

;;(req->filename #f)
(define (req->filename r)
  (create-directory (store-root) #t)
  (make-pathname (store-root)
                 (conc (time->string (seconds->utc-time) "%Y-%m") ".scm")))

;; append object to filename and flush.
(define (save object filename)
  (let ((port (open-output-file* (file-open filename (+ open/write open/append open/creat)))))
    (pp object port)
    (close-output-port port)))

(define (app r)
  ;; try to make a serializeable scheme object from request (replace
  ;; records with lists etc)
  (let ((reqobj `((ts . ,(current-seconds))
                  (remote . ,(remote-address))
                  ,@(map->alist (map-update-in r '(uri) uri->list)))))

    ;; write directly to file:
    (save reqobj (req->filename r))
    ;; write to stderr too for nice debugging:
    (with-output-to-port (current-error-port)
      (lambda () (pp reqobj) (flush-output)))

    (response body: "{\"status\" : \"ok\"}\n")))

(define handler (wrap-errors (wrap-log app)))

(define nrepl-thread  (thread-start! (lambda () (nrepl (+ 1 (server-port))))))
(define server-thread (thread-start! (lambda () (reser-start (lambda (r) (handler r))))))


(thread-join! server-thread)
