;;; log stdout to a server using http(s)
;;; it'll do a start post: url/start
;;; it'll do url/stdout and url/stderr posts for data from subprocess
;;; and then it'll do an url/exit post with exit status
;;; 
;;; Copyright Adellica ® 2015
(use posix srfi-13 http-client uri-common intarweb posix)

;; TODO: append a random token to url which works as a "session token"
;; TODO: better control of buffering (max 1MB per post and at most every 1 second?)

;; process*'s input-ports don't support port->fileno se we need to do
;; this ourselves.
;;
;; returns 3 values:
;; - pid
;; - child's stdou
;; - child's stderr
(define (spawn* cmd #!optional (args '()) env)
  (let*-values
      (;;((in-in   in-out) (create-pipe))
       ((out-in out-out) (create-pipe))
       ((err-in err-out) (create-pipe))
       ((pid) (process-fork
               (lambda ()
                 ;;(duplicate-fileno in-in fileno/stdin)
                 (duplicate-fileno out-out fileno/stdout)
                 (duplicate-fileno err-out fileno/stderr)
                 ;;(file-close  in-in) (file-close in-out)
                 (file-close out-in) (file-close out-out)
                 (file-close err-in) (file-close err-out)
                 (process-execute cmd args env)) #t)))

    ;;(file-close in-in)
    (file-close out-out)
    (file-close err-out)

    (values pid out-in err-in)))

(define urlp (make-parameter #f))

(cond ((= 0 (length (command-line-arguments)))
       (print "usage: " (car (argv)) " <url> <command> <arg> ...")
       (exit -1)))

;; (urlp "http://localhost:8080/")
(urlp (car (command-line-arguments)))
(command-line-arguments (cdr (command-line-arguments)))

;; read up to 1k at a time. lot's of realloc so it's nice and slow
(define (fd-read fd)
  (let* ((read (file-read fd 1024))
         (buffer (car read))
         (bytes (cadr read)))
    (substring buffer 0 bytes)))

(define (->uri url) (if (uri? url) url (uri-reference url)))

(define (update-path url proc)
  (let ((uri (->uri url)))
    (update-uri uri path: (proc (uri-path uri)))))

(define (append-path url path)
  (update-path
   url
   (lambda (p)
     ;; delete "" in path
     (filter (lambda (s) (not (equal? s "")))
             (append p (list path))))))

(define (push-data url str)
  (with-input-from-request url str read-string))


(begin

  (define-values (pid cout cerr)
    (spawn* "/bin/sh"
            `("-c" ,(string-intersperse (command-line-arguments)))))

  (##sys#file-nonblocking! cout)
  (##sys#file-nonblocking! cerr))

(push-data (append-path (urlp) "started") "")

(define-values
  (exit-status normal?)
  (let loop ()
    (let ((fds (file-select (list cout cerr) #f)))
      (if (member cout fds)
          (push-data (append-path (urlp) "stdout") (fd-read cout))
          (push-data (append-path (urlp) "stderr") (fd-read cerr)))
      (let-values ( ( (pid normal? exit-status)
                      (process-wait pid #t)))
        (if (= 0 pid) ;; still running
            (loop)
            (values exit-status normal?))))))

(file-close cout)
(file-close cerr)

(push-data (append-path (urlp) "exit")
           (conc (if normal? "normal" "signal")
                 " exit "
                 (number->string exit-status)))


;; add query parameters:
;; - pid
;; - cmdline
;; - timestamp
;; - mac addresses
;; - client (nlog) version



