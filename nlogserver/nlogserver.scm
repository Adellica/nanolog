(use files spiffy intarweb uri-common srfi-18 nrepl reser persistent-hash-map posix)

(define store-root (make-parameter #f))
;; (command-line-arguments '("./" "8080" "--ssl"))
(define cla command-line-arguments)
(cond ((>= (length (cla)) 2)
       (store-root (car (cla)))
       (server-port (string->number (cadr (cla)))))
      (else (error "usage: <storage-path> <port> [--ssl]")))

(system "ip -4 -o a") ;; give a hint on which url the server can be reached on

;;(req->filename #f)
(define (req->filename r)
  (create-directory (store-root) #t)
  (make-pathname (store-root)
                 (conc (time->string (seconds->utc-time) "%Y-%m") ".scm")))

;; append object to filename and flush.
(define (save object filename)
  (let ((port (open-output-file* (file-open filename (+ open/write open/append open/creat)))))
    (write object port)
    (newline port)
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

(define server #f)
(cond ((member "--ssl" (cla))
       ;; https on (server-port)
       (use openssl)
       (define listener (ssl-listen (server-port)))
       (ssl-load-certificate-chain! listener "/etc/ssl/server.crt")
       (ssl-load-private-key! listener "/etc/ssl/server.key")
       (set! server (lambda () (accept-loop listener ssl-accept))))
      (else
       ;; http on (server-port)
       (set! server (lambda () (start-server)))))

(define nrepl-thread  (thread-start! (lambda () (nrepl (+ 1 (server-port))))))
(define server-thread
  (thread-start! (lambda ()
                   (vhost-map `((".*" . ,(lambda (c) (reser-handler handler)))))
                   (server))))

(thread-join! server-thread)
