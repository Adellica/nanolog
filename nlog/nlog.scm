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

(if (find (cut equal? "-h" <>) (cla))
    (error "usage: [-m \"msg\"] [-u http://host.com:port] [/some/path/for/tagging]"))


;; #f or string
(define (mac interface)
  (let ((file (conc  "/sys/class/net/" interface "/address")))
   (and (regular-file? file)
        (with-input-from-file file read-line))))
;; (map mac '("wlan0" "eth0" "gone"))

(define path (make-parameter (or (find (cut string-prefix? "/" <>) (cla)) "/")))
(define base-url (make-parameter (or (option-do "-u" (cla)) "https://nanolog-tr.adellica.com")))
(define msg (make-parameter (option-do "-m" (cla)))) ;; string or #f for stdin

(define metadata
  (let ((msgnum 0))
   (lambda ()
     `((pid ,(current-process-id)) ;; if we send multiple lines
       (msgnum ,(let ((out msgnum)) (set! msgnum (add1 msgnum)) out)) ;; 0-indexed
       (pcmdline ,(cmdline (parent-process-id)))
       (ts ,(current-seconds))
       (wlan0 , (or (mac "wlan0") "N/A"))
       (eth0 , (or (mac "eth0") "N/A"))
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
