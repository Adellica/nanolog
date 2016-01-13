;; log to a server directly without any daemoning
(use http-client uri-common intarweb posix medea nanomsg)

;; linux-only obviously. string contains \x00-characters!
(define (cmdline* pid)
  (with-input-from-file (conc "/proc/" pid "/cmdline") read-string))
(define (cmdline pid) ;; stringify, keeping \x00 etc
  (with-output-to-string (lambda () (write (cmdline* pid)))))
;; (cmdline (current-process-id))

(define debug? (make-parameter #f))

;; default seed is second precision. this creates problems when we
;; spawn nlog multiple times within the same second.
;;
;; hack: fx+ does no type-checking and will use 64 bit doubles as
;; 32-bit ints or similar. it should still give us the "randomness"
;; that we need, though.
(randomize (fx+ (fx+ (current-seconds)
                     (current-milliseconds))
                (current-process-id)))

;; generate a random hex-string of length n
(define (uid n)
  (string-join
   (list-tabulate n (lambda (x) (string-pad (format #f "~x" (random 256)) 2 #\0)))
   ""))

;; ==================== config ====================
;; #f or a colon-formatted MAC string

;; default sock file. override in setup-file
(define ipc (make-parameter "ipc:///tmp/nanolog.sock"))

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
(define counter (let ((c 0)) (lambda () (let ((cc c)) (set! c (+ 1 c)) cc))))
(define ts current-seconds)
(define properties
  (make-parameter
   `((seq . ,counter) ;; call counter on every create-message
     (ts  . ,ts)    ;; call ts on every create-message
     (sid . ,(session-id)))))

;; execute configure script (should overwrite parameters)
(let ((config-file "/etc/nanolog.config.scm"))
  (if (regular-file? config-file)
      (load config-file)))

;; make turn procedure values into their call-results (they should
;; return JSON-serializable values).
;; (pp (format-properties))
(define (format-properties #!optional (properties (properties)))
  (map (lambda (pair) (cond ((procedure? (cdr pair)) (cons (car pair) ((cdr pair))))
                       (else pair)))
       properties))

;; (define message (create-message "i like cake"))
(define (create-message body)
  `((body . ,body) ,@(format-properties)))

(define (message->request message)
  (make-request uri: (uri-reference (alist-ref 'url message))
                method: 'POST
                body: (alist-ref 'body message)))


(define (debug-print message)
  (print ";; message dump")
  (write-json message)
  (newline))

;; TODO: append mac address
;; TODO: cla for relative url?
;; message is alist or string (string should be JSON then)
(define (send-log-http message)
  (if (debug?)
      (debug-print message)
      (for-each
       (lambda (server)
         (with-input-from-request server
                                  (if (string? message) message
                                      (json->string message))
                                  read-string))
       (servers))))

(define (assert-valid-ipc #!optional (endpoint (ipc)))
  (define ipc? (string-prefix? "ipc://" endpoint))
  (if ipc?
      (if (not (socket? (substring endpoint (string-length "ipc://"))))
          (error "nonexisting ipc (nlogd running?) see `ipc` config parameter)"
                 endpoint))
      #t))

;; message is string (should be json) or alist
(define (send-log-nanomsg message)
  (if (debug?)
      (debug-print message)
      (begin
        (assert-valid-ipc)
        (define socket (nn-socket 'req))
        (nn-connect socket (ipc))
        (nn-send socket (if (string? message) message (json->string message)))
        (print (nn-recv socket)))))

;; (send-log-http (create-message "oh oh"))
