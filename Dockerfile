#!UseOBSRepositories

#!BuildTag: rancher/hardened-etcd:v3.4.7
#!BuildTag: rancher/hardened-etcd:latest
#!BuildName: hardened-etcd

# INFO: image-build-base:latest provides the following:
# - required packages (make, musl-gcc, musl-libc-static, etc)
# - set CC, and C_INCLUDE_PATH evironment variables, to enable building with musl libc

ARG GO_IMAGE=rancher/image-build-base:latest

# INFO(psaggu): keeping the following commented instructions
# to do a final review pass once after RKE2 build is e2e tested.
# FROM ${GO_IMAGE} as base-builder
# FROM base-builder as etcd-builder

FROM ${GO_IMAGE} as etcd-builder
# setup the build
ARG TARGETARCH
ARG PKG=go.etcd.io/etcd
ARG SRC=github.com/k3s-io/etcd
ARG TAG="v3.5.13-k3s1"

COPY etcd ${GOPATH}/src/${PKG}
ADD vendor.tar.gz ${GOPATH}/src/${PKG}
ADD vendor-etcdctl.tar.gz ${GOPATH}/src/${PKG}/etcdctl
ADD vendor-server.tar.gz ${GOPATH}/src/${PKG}/server
    
WORKDIR ${GOPATH}/src/${PKG}

# cross-compilation setup
ARG TARGETPLATFORM
# build and assert statically linked executable(s)
RUN export GO_LDFLAGS="-linkmode=external -X ${PKG}/version.GitSHA=$(git rev-parse --short HEAD)" && \
    if echo ${TAG} | grep -qE '^v3\.4\.'; then \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/etcd . && \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/etcdctl ./etcdctl; \
    else \
        cd $GOPATH/src/${PKG}/server  && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcd . && \
        cd $GOPATH/src/${PKG}/etcdctl && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o ../bin/etcdctl .; \
    fi

# RUN go-assert-static.sh bin/*
ARG ETCD_UNSUPPORTED_ARCH
ENV ETCD_UNSUPPORTED_ARCH=$ETCD_UNSUPPORTED_ARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
	    go-assert-boring.sh bin/*; \
    fi
RUN install bin/* /usr/local/bin

FROM ${GO_IMAGE} as strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=etcd-builder /usr/local/bin/ /usr/local/bin
RUN rm /usr/local/bin/go-*.sh; \
    for bin in $(ls /usr/local/bin); do \
        strip /usr/local/bin/${bin}; \
    done
RUN etcd --version; \
    etcdctl version

FROM scratch
ARG ETCD_UNSUPPORTED_ARCH
LABEL org.opencontainers.image.source="https://github.com/rancher/image-build-etcd"
ENV ETCD_UNSUPPORTED_ARCH=$ETCD_UNSUPPORTED_ARCH
COPY --from=strip_binary /usr/local/bin/ /usr/local/bin/



