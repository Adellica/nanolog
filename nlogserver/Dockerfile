## Dockerfile for nlogserver
## typically ran like this:
## docker build -t adellica/nlogserver .

FROM adellica/base

RUN mkdir /etc/service/nlogserver
RUN printf "#!/bin/sh \n\
exec nlogserver /var/log/nlogserver 443 --ssl \
" > /etc/service/nlogserver/run && \
  chmod a+x /etc/service/nlogserver/run

EXPOSE 443

ADD . /tmp/nlogserver
RUN cd /tmp/nlogserver && \
    chicken-install -s && \
    rm -r /tmp/nlogserver
