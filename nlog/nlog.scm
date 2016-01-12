;; log to a server directly without any daemoning
(use http-client uri-common intarweb posix)
(define cla command-line-arguments)

;; linux-only obviously. string contains \x00-characters!
(define (cmdline* pid)
  (with-input-from-file (conc "/proc/" pid "/cmdline") read-string))
(define (cmdline pid) ;; stringify, keeping \x00 etc
  (with-output-to-string (lambda () (write (cmdline* pid)))))
;; (cmdline (current-process-id))


;; (option-do "-m" '("hi" "-m" "message!"))
(define (option-do option args)
  (let ((rest (find-tail (cut equal? option <>) args)))
    (cond ((and rest (pair? (cdr rest)))
           (let ((x (cadr rest)))
             (if (string-prefix? "-" x) #f x)))
          (else #f))))

(define debug? (member "-d" (cla)))

(if (find (cut equal? "-h" <>) (cla))
    (error "usage: [msg...] [-u http://host.com:port] [/some/path/for/tagging] [-d (debug)]"))

;; #f or string
(define (mac interface)
  (let ((file (conc  "/sys/class/net/" interface "/address")))
   (and (regular-file? file)
        (with-input-from-file file read-line))))

(define session-id
  (let ((sid (string-join
              (list-tabulate 10
                             (lambda (x) (string-pad
                                     (format #f "~x" (random 256)) 2 #\0)))
              "")))
    (lambda () sid)))


(define (default-config key)q
  (handle-exceptions
   e (begin (print "***** error when reading /etc/nanolog.config.scm")
            (raise e))
   (alist-ref key (eval `(begin ,@(with-input-from-file "/etc/nanolog.config.scm"
                                    (lambda () (port-map identity read))))))))

(define (default-base-url) (string-intersperse (default-config 'url) ""))
(define (config-headers) (default-config 'headers))
;; (map mac '("wlan0" "eth0" "gone"))

(define path (make-parameter (or (find (cut string-prefix? "/" <>) (cla)) "/")))
(define base-url (make-parameter (or (option-do "-u" (cla)) (default-base-url))))
(define msg (make-parameter (option-do "-m" (cla)))) ;; string or #f for stdin

(define metadata
  (let ((msgnum 0))
   (lambda ()
     `((pid ,(current-process-id)) ;; if we send multiple lines
       (msgnum ,(let ((out msgnum)) (set! msgnum (add1 msgnum)) out)) ;; 0-indexed
       (pcmdline ,(cmdline (parent-process-id)))
       (ts ,(current-seconds))
       ,@(config-headers)
       (cid "LyJI9G5891jnDhvO5UPMxW63MRI="))))) ;; 160-bit client id TODO: use git commit

;; (pp (metadata))

;; TODO: append mac address
;; TODO: cla for relative url?
(define (send-log-http msg)
  (with-input-from-request (make-request uri: (uri-reference (conc (base-url) (path)))
                                         headers: (headers (metadata)))
                           msg read-string))

;; (send-log-http "hi from repl")

(if (msg) ;; msg from cla?
    (send-log-http (msg)) ;; send it all
    (port-for-each send-log-http read-line) ;; send line by line
    )
