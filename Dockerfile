FROM ubuntu:22.04

RUN apt-get update && apt-get install -y ca-certificates

COPY dist/aserver-linux-amd64 /usr/bin/aserver
RUN chmod +x /usr/bin/aserver

CMD ["/usr/bin/aserver"]
