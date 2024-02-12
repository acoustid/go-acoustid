FROM ubuntu:22.04

COPY dist/aserver-linux-amd64 /aserver

CMD ["/aserver"]
