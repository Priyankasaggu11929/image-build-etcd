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

COPY ./ ${GOPATH}/src/${PKG}/
WORKDIR ${GOPATH}/src/${PKG}
RUN ls ${GOPATH}/src/${PKG}/


