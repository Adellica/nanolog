
# nlog

Client-side endpoint. You should be able to do this:

```
 $ nlog hello world. i like cake
 ```

And that message will be sent to `nlogd` via IPC.


# nlogd

This is the `nanolog` client daemon. It accepts messages from IPC and forwards them to the `nlogserver`. It has the following tasks:

- Buffer messages when they can't be sent (eg. when offline)
- Chunk messages into suitably-sized HTTP requests


## config

Want to test nlogd / nlog? Try this:
```
$ echo '((url . "http://127.0.0.1:8080/"))' >> /etc/nanolog.config.scm
```
