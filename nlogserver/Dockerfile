FROM adellica/chicken
RUN apt-get update && apt-get -y install git

# should be ran automatically by chicken-install, but this saves us
# from installing all dependencies each time.
RUN chicken-install nrepl spiffy matchable intarweb uri-common medea clojurian filepath test crypt
RUN chicken-install persistent-hash-map

RUN git clone https://github.com/Adellica/reser.git && cd reser && chicken-install -s && cd .. && rm -r reser

EXPOSE 8080
ENTRYPOINT  ["/usr/local/bin/nlogserver"]
CMD []

ADD . /tmp/nlogserver

RUN cd /tmp/nlogserver && \
    chicken-install -s && \
    rm -r /tmp/nlogserver
