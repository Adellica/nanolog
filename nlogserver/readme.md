
# nlogserver

This piece of software runs on your server. It basically just accepts
incoming HTTP requests and saves them to disk. It does not support
reading the log-files it saves (separate project for that).

## Format

Logs are stored as plain Scheme objects. For example:

```scheme
((ts . 1452684676.0)
 (remote . "82.134.78.42")
 (uri . "https://nanolog-tr.adellica.com/nanolog")
 (headers
   .
   #(headers:
     ((content-type #(application/x-www-form-urlencoded ()))
      (content-length #(12 ()))
      (accept #(*/* ()))
      (user-agent #((("curl" "7.46.0" #f)) ()))
      (host #(("nanolog-tr.adellica.com" . #f) ())))))
 (method . POST)
 (msg . "testing this"))
```

Note that nlogserver accepts incomming connections on any url (which
is then simply logged).
