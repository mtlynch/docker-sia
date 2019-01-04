FROM golang AS builder
LABEL maintainer="Michael Lynch <michael@mtlynch.io>"

ENV GOOS linux
ENV GOARCH amd64
ENV CGO_ENABLED 0

ARG TOXIC_COMMIT="93cc7437fc362b8f58521a0ffa9fb459b31e4578"

RUN go get -d -u gitlab.com/NebulousLabs/Sia/... && \
    go get -d -u github.com/dchest/threefish/... && \
    cd $GOPATH/src/gitlab.com/NebulousLabs/Sia && \
    git checkout "$TOXIC_COMMIT" && \
    make release

FROM alpine
LABEL maintainer="Michael Lynch <michael@mtlynch.io>"

ENV SIA_DIR /sia
ENV SIA_DATA_DIR="/sia-data"
ENV SIA_MODULES gctwhr

RUN apk --no-cache add socat

WORKDIR "$SIA_DIR"
COPY --from=builder /go/bin/siad ./
COPY --from=builder go/bin/siac ./
ENTRYPOINT socat tcp-listen:9980,reuseaddr,fork tcp:localhost:8000 & \
  ./siad \
    --modules "$SIA_MODULES" \
    --sia-directory "$SIA_DATA_DIR" \
    --api-addr "localhost:8000"
