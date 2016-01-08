
# nlogd

This is the `nanolog` daemon. It accepts messages from IPC and forwards them to the `nlogserver`. It has the following tasks:

- Buffer messages when they can't be sent (eg. when offline)
- Chunk messages into suitably-sized HTTP requests


## config

```
((url . "http://127.0.0.1/"))
```
