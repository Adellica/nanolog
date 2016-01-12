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

;; ====================


(define (config #!optional key)
  (define conf-alist
    (handle-exceptions
     e (begin (print "***** error when reading /etc/nanolog.config.scm")
              (raise e))
     (eval `(begin
              ,@(with-input-from-file "/etc/nanolog.config.scm"
                  (lambda () (port-map identity read)))))))
  (if key (alist-ref key conf-alist) conf-alist))


(define create-message
  (let ((msgnum 0))
    (lambda (body)
      ;; TODO: add client version identifier
      `((msgnum . ,(let ((out msgnum)) (set! msgnum (add1 msgnum)) out)) ;; 0-indexed
        (pcmdline . ,(cmdline (parent-process-id)))
        (ts . ,(current-seconds))
        (body . ,body)
        ,@ (config)))))

;; (define message (create-message "i like cake"))
;; (pp message)

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
