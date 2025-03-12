#!UseOBSRepositories

#!BuildTag: rancher/image-build-etcd:v3.4.7
#!BuildTag: rancher/image-build-etcd:latest
#!BuildName: image-build-etcd

ARG GO_IMAGE=rancher/image-build-base:latest

FROM ${GO_IMAGE} as base-builder


RUN set -euo pipefail; \
    zypper -n install --no-recommends \
    # file \
    gcc \
    # git \
    clang7 \
    llvm \
    lld \
    make; \
    zypper -n clean; \
    rm -rf {/target,}/var/log/{alternatives.log,lastlog,tallylog,zypper.log,zypp/history,YaST2}


FROM base-builder as etcd-builder
# setup the build
ARG TARGETARCH
ARG PKG=go.etcd.io/etcd
ARG SRC=github.com/k3s-io/etcd
ARG TAG="v3.5.13-k3s1"

COPY etcd ${GOPATH}/src/${PKG}
ADD vendor.tar.gz ${GOPATH}/src/${PKG}
    
WORKDIR ${GOPATH}/src/${PKG}
RUN ls ${GOPATH}/src/${PKG}/; \
    ls ${GOPATH}/src/${PKG}/vendor/

# cross-compilation setup
ARG TARGETPLATFORM
# build and assert statically linked executable(s)
RUN export GO_LDFLAGS="-linkmode=external -X ${PKG}/version.GitSHA=$(git rev-parse --short HEAD)" && \
    if echo ${TAG} | grep -qE '^v3\.4\.'; then \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor -o bin/etcd . && \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor  -o bin/etcdctl ./etcdctl; \
    else \
        cd $GOPATH/src/${PKG}/server  && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor -o ../bin/etcd . && \
        cd $GOPATH/src/${PKG}/etcdctl && go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor -o ../bin/etcdctl .; \
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
RUN for bin in $(ls /usr/local/bin); do \
        strip /usr/local/bin/${bin}; \
    done
RUN etcd --version

FROM scratch
ARG ETCD_UNSUPPORTED_ARCH
LABEL org.opencontainers.image.source="https://github.com/rancher/image-build-etcd"
ENV ETCD_UNSUPPORTED_ARCH=$ETCD_UNSUPPORTED_ARCH
COPY --from=strip_binary /usr/local/bin/ /usr/local/bin/



