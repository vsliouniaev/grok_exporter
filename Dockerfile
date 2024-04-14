FROM golang as builder

ARG ONIG_VERS=6.9.9

#------------------------------------------------------------------------------
# Create a statically linked Oniguruma library for Linux amd64
#------------------------------------------------------------------------------

# This will create /usr/local/lib/libonig.a

RUN cd /tmp && \
    curl -sLO https://github.com/kkos/oniguruma/releases/download/v${ONIG_VERS}/onig-${ONIG_VERS}.tar.gz && \
    tar xfz onig-${ONIG_VERS}.tar.gz   && \
    rm onig-${ONIG_VERS}.tar.gz        && \
    cd /tmp/onig-${ONIG_VERS}          && \
    ./configure                        && \
    make                               && \
    make install

WORKDIR /go/src/github.com/fstab/grok_exporter
COPY . .
RUN ls /usr/local/lib/libonig.a
ENV CGO_LDFLAGS=/usr/local/lib/libonig.a
RUN go mod download
## Statically link c like this so we don't need to download extra packages in alpine
RUN go build -ldflags "-linkmode 'external' -extldflags '-static'" -o /bin/grok-exporter
RUN git submodule update --init --recursive
RUN go test ./... --race

FROM  alpine:latest
## If static linking does not work fully we can download the required c libs like this
# RUN apk --no-cache add libc6-compat 
USER 65532:65532
COPY --from=builder /go/src/github.com/fstab/grok_exporter/logstash-patterns-core/patterns /patterns
COPY --from=builder /bin/grok-exporter /bin/grok-exporter
EXPOSE 9144

ENTRYPOINT [ "/bin/grok-exporter", "-config", "/grok/config.yml" ]