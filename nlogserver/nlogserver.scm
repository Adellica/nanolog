(use files spiffy intarweb uri-common srfi-18 nrepl posix)


;; ==================== reser ====================
;; TODO: release reser egg and make don't embed it here
(define (request-string!)
  ;; TODO: what to do is we have more than 16MB? we can't just ignore it all.
  (read-string (min (* 16 1024 1024) ;; <- max 16MB
                    (or (header-value 'content-length (request-headers (current-request))) 0))
               (request-port (current-request))))

(define (reser-handler handler)

  (define request `((body    . ,(request-string!))
                    (uri     . ,(request-uri (current-request)))
                    (headers . ,(request-headers (current-request)))
                    (method  . ,(request-method (current-request)))))

  (define resp (handler request))

  (send-response body:    (or (alist-ref 'body resp) "")
                 status:  (alist-ref 'status resp)
                 code:    (alist-ref 'code resp)
                 reason:  (alist-ref 'reason resp)
                 headers: (or (alist-ref 'headers resp) '())))
;; construct a response object
(define (response #!key body status code reason headers)
  `((body    . ,body)
    (status  . ,status)
    (code    . ,code)
    (reason  . ,reason)
    (headers . ,headers)))

;; ====================       ====================

(define (warn . args)
  (with-output-to-port (current-error-port)
    (lambda () (apply print args))))

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

;; make sure x is serializable
(define (serializable x)
  (cond ((list? x) (map serializable x))
        ((vector? x) (list->vector (map serializable (vector->list x))))
        ((relative-ref? x) (uri->list x))
        (else x)))
;; (serializable `(1 #( ,(make-uri) ) 2))

(define (app r)
  ;; try to make a serializeable scheme object from request (replace
  ;; records with lists etc)
  (let ((reqobj (serializable
                 `((ts . ,(current-seconds))
                   (remote . ,(remote-address))
                   ,@r))))

    ;; write directly to file:
    (save reqobj (req->filename r))
    ;; write to stderr too for nice debugging:
    (with-output-to-port (current-error-port)
      (lambda () (pp reqobj) (flush-output)))

    (response body: "{\"status\" : \"ok\"}\n")))

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
                   (vhost-map `((".*" . ,(lambda (c) (reser-handler (lambda (r) (app r)))))))
                   (server))))

(thread-join! server-thread)
