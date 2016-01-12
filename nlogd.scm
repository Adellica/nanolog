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
  (condition-case
   (send-log-http message)
   (e (exn i/o net)
      (print "nlogd error: "
             (get-condition-property e 'exn 'message))
      ;; calm down a bit
      (thread-sleep! 1)
      #f)
   (e ()
      (pp (condition->list e) (current-error-port))
      #f)))

(let loop ()
  (handle-exceptions
   e (pp (condition->list e))
   (if (queue-empty? messages)
       (thread-sleep! 0.1)
       (let ((msg (queue-remove! messages)))
         (if (process-message msg)
             (pp `(msg sent ,msg))
             ;; could not send message, push it back and so we'll try
             ;; again later
             (queue-push-back! messages msg)))))
  (loop))
