;; log to a server directly without any daemoning
(use http-client uri-common intarweb posix medea)

;; linux-only obviously. string contains \x00-characters!
(define (cmdline* pid)
  (with-input-from-file (conc "/proc/" pid "/cmdline") read-string))
(define (cmdline pid) ;; stringify, keeping \x00 etc
  (with-output-to-string (lambda () (write (cmdline* pid)))))
;; (cmdline (current-process-id))

(define debug? (make-parameter #f))

;; generate a random hex-string of length n
(define (uid n)
  (string-join
   (list-tabulate n (lambda (x) (string-pad (format #f "~x" (random 256)) 2 #\0)))
   ""))

;; ==================== config ====================
;; #f or a colon-formatted MAC string
(define (mac interface)
  (let ((file (conc  "/sys/class/net/" interface "/address")))
   (and (regular-file? file)
        (with-input-from-file file read-line))))

;; session id is generated per nlog process invoking. there can be
;; multiple messages within a session (eg. multiple lines)
(define session-id
  (let ((sid (uid 10)))
    (lambda () sid)))

(define servers (make-parameter '("http://localhost:8080/")))
(define count (let ((c 0)) (lambda () (let ((cc c)) (set! c (+ 1 c)) cc))))
(define ts current-seconds)
(define properties
  (make-parameter
   `((seq . ,count) ;; call count on every create-message
     (ts  . ,ts)    ;; call ts on every create-message
     (sid . ,(session-id)))))

;; execute configure script (should overwrite parameters)
(let ((config-file "/etc/nanolog.config.scm"))
  (if (regular-file? config-file)
      (load config-file)))

;; (format-properties)
(define (format-properties #!optional (properties (properties)))
  (map (lambda (pair) (cond ((procedure? (cdr pair)) (cons (car pair) ((cdr pair))))
                       (else pair)))
       properties))

;; (define message (create-message "i like cake"))
(define create-message
  (let ((msgnum 0))
    (lambda (body)
      ;; TODO: add client version identifier?
      `((body . ,body) ,@(format-properties)))))

(define (message->request message)
  (make-request uri: (uri-reference (alist-ref 'url message))
                method: 'POST
                body: (alist-ref 'body message)))

;; TODO: append mac address
;; TODO: cla for relative url?
(define (send-log-http message)
  (if (debug?)
      (begin (print ";; this is a message HTTP request dump (content-length will appera in real request)")
             (write-request (update-request (message->request message) port: (current-error-port)))
             (write-json message (current-error-port))
             (newline (current-error-port)))
      (with-input-from-request (message->request message)
                               (json->string (alist-delete 'url message))
                               read-string)))


;; (send-log-http (create-message "oh oh"))
