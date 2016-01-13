(include "libnlog.scm")

(use nanomsg medea)

(define verbose? (make-parameter #f))

(if (member "-d" (command-line-arguments))
    (verbose? #t))

(define socket (nn-socket 'rep))
(nn-bind socket (ipc))
(print "nlogd: listening on " (ipc))
(print "nlogd: proxying messages to " (servers))

;; TODO: use a thread-safe queue here.
(define messages (make-queue))

(define nn-thread
  (thread-start!
   (lambda ()
     (let loop ()
       ;; expecting message as JSON string
       (handle-exceptions
        e (begin (pp (condition->list e))
                 (thread-sleep! 1))
        (let* ((msgstr (nn-recv socket))
               (msg (or (read-json msgstr)
                        (error "invalid JSON from nlog client" msgstr))))
          (if (verbose?) (pp `(msg added ,msg)))
          (queue-add! messages msg)
          (nn-send socket (conc "{\"enqueued\" : " (queue-length messages) "}"))))
       (loop)))))

(define *backoff* 1)
;; max 1024 seconds ~17min
(define (backoff!)
  (thread-sleep! *backoff*)
  (set! *backoff* (min (* 10 #|minutes|# 60) (* *backoff* 2))))
(define (clear-backoff!)
  (set! *backoff* 1))

(define (process-message message)
  (condition-case
   (begin (send-log-http message)
          (clear-backoff!))
   (e (exn i/o net)
      (print "nlogd error: "
             (get-condition-property e 'exn 'message)
             " (sleeping for " *backoff* " seconds)")
      (backoff!)
      #f)
   (e ()
      (pp (condition->list e) (current-error-port))
      (backoff!)
      #f)))

(let loop ()
  (handle-exceptions
   e (pp (condition->list e))
   (if (queue-empty? messages)
       (thread-sleep! 0.1)
       (let ((msg (queue-remove! messages)))
         (if (process-message msg)
             (if (verbose?) (pp `(msg sent ,msg)))
             ;; could not send message, push it back and so we'll try
             ;; again later
             (queue-push-back! messages msg)))))
  (loop))

