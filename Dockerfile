FROM ubuntu:22.04

RUN apt-get update && apt-get install -y ca-certificates

COPY dist/aserver-linux-amd64 /aserver
RUN chmod +x /aserver

CMD ["/aserver"]
