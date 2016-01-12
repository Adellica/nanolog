(use files spiffy intarweb uri-common srfi-18 nrepl posix medea)


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

;; make sure x is serializable. convert uri-records to lists etc.
(define (serializable x)
  (cond ((pair? x) (cons (serializable (car x)) (serializable (cdr x))))
        ((vector? x) (list->vector (map serializable (vector->list x))))
        ((or (uri? x) (relative-ref? x)) (uri->string x))
        (else x)))
;; (serializable `(1 #( ,(make-uri) ) 2))
;; (serializable `((id . ,(uri-reference "http://a.com"))))


(define (app-saver r)
  ;; try to make a serializeable scheme object from request (replace
  ;; records with lists etc)
  (let ((reqobj (serializable
                 `((ts . ,(current-seconds))
                   (remote . ,(remote-address))
                   ,@r))))

    ;; convert body from json to scheme, if possible. otherwise, just
    ;; keep it as a string. request payload as a string:
    (define body (alist-ref 'body reqobj))

    ;; rename body (request-body) to msg. msg typically contains a
    ;; body field too (body of the message).
    (define req (alist-update 'msg (or (read-json body) body)
                              (alist-delete 'body reqobj)))
    ;; write directly to file:
    (save req (req->filename r))
    ;; write to stderr too for nice debugging:
    (with-output-to-port (current-error-port)
      (lambda () (pp req) (flush-output)))

    (response body: "{\"status\" : \"ok\"}\n")))

(define (app r)
  (if (equal? 'POST (alist-ref 'method r))
      (app-saver r)
      (begin (warn "ignoring GET " (alist-ref 'uri r))
             (response status: 'bad-request body: "illegal request\n"))))

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
