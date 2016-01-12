;;; Example config file for nanolog. This file is evaluated once for
;;; every nlog startup. Procedures in the properties alist will be
;;; called with 0 arguments.
;;;
;;; Every message will be constructed with the "body" property added
;;; containing the message body string (from the command-line or
;;; read-line) to the property parameter below.
;;;
;;; (print "loading nanolog config")

(servers (list "http://127.0.0.1:8080/klm/test/"))

(properties
 `(,@(properties)
   (wlan0 . ,(or (mac "wlan0") "N/A"))
   (eth0 . ,(or (mac "eth0") "N/A"))))
