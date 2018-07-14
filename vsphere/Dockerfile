# Build the Go binaries using a multi-stage build phase named "golang"
FROM golang:1.10.3-alpine3.7 as golang
LABEL maintainer="Hui Luo <luoh@vmware.com>"

RUN apk --no-cache add git

ENV GOVC_VERSION=0.18.0
RUN go get -d github.com/vmware/govmomi && \
    git --work-tree /go/src/github.com/vmware/govmomi \
        --git-dir /go/src/github.com/vmware/govmomi/.git \
        checkout -b v${GOVC_VERSION} v${GOVC_VERSION} && \
    go install github.com/vmware/govmomi/govc

#FROM crosscloudci/debian-go:latest
FROM alpine:3.7
LABEL maintainer="Denver Williams <denver@debian.nz>"

# Install some common dependencies
RUN apk --no-cache add git bash

COPY --from=golang /go/bin/govc /usr/local/bin/
COPY scripts/template.sh /cncf/
COPY input.tf /cncf/

RUN chmod +x /cncf/template.sh
WORKDIR /cncf/

CMD ["bash", "-c", "/cncf/template.sh"]
