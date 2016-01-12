(include "libnlog.scm")

(use nanomsg medea)


(define socket (nn-socket 'rep))
(nn-bind socket (ipc))
(print "nlogd: listening on " (ipc))

;; TODO: use a thread-safe queue here.
(define messages (make-queue))

(define nn-thread
  (thread-start!
   (lambda ()
     (let loop ()
       ;; expecting message SCHEME as string
       (handle-exceptions
        e (begin (pp (condition->list e))
                 (thread-sleep! 1))
        (let* ((msgstr (nn-recv socket))
               (msg (or (read-json msgstr)
                        (error "invalid JSON from nlog client" msgstr))))
          (pp `(msg added ,msg))
          (queue-add! messages msg)
          (nn-send socket (conc "{\"enqueued\" : " (queue-length messages) "}"))))
       (loop)))))

(define (process-message message)
  (handle-exceptions
   e (begin
       (pp (condition->list e))
       (thread-sleep! 1) ;; no need to flood with messages etc
       #f)
   (send-log-http message)))

(let loop ()
  (handle-exceptions
   e (pp (condition->list e))
   (if (queue-empty? messages)
       (thread-sleep! 0.1)
       (let ((msg (queue-remove! messages)))
        (if (not (process-message msg))
            ;; could not send message, push it back and so we'll try
            ;; again later
            (queue-push-back! messages msg)
            (pp `(msg sent ,msg))))))
  (loop))
