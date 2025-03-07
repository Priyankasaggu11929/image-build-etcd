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
    make; \
    zypper search lld; \
    zypper -n clean; \
    rm -rf {/target,}/var/log/{alternatives.log,lastlog,tallylog,zypper.log,zypp/history,YaST2}
