ARG BASE_IMAGE=docker.io/library/ubuntu:24.04

####################################################################################################
# Builder
####################################################################################################
FROM $BASE_IMAGE AS builder

# If set to "stable", we resolve the real version in RUN below.
ARG KUBECTL_VERSION="stable"
ARG AKUITY_VERSION="stable"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y ca-certificates wget && \
  ARCH=$(uname -m); \
  case "$ARCH" in \
    x86_64) ARCH=amd64 ;; \
    aarch64) ARCH=arm64 ;; \
    armv7l|armv6l) ARCH=arm ;; \
    arm64|armv8*) ARCH=arm64 ;; \
  esac && \
  \
  # Resolve kubectl "stable" to real version
  if [ "$KUBECTL_VERSION" = "stable" ]; then \
    KUBECTL_VERSION=$(wget -qO- https://dl.k8s.io/release/stable.txt); \
  fi && \
  echo "Using kubectl version: $KUBECTL_VERSION" && \
  wget -qO /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
  chmod +x /usr/local/bin/kubectl && \
  \
  # Resolve akuity CLI "stable" to real version
  if [ "$AKUITY_VERSION" = "stable" ]; then \
    AKUITY_VERSION=$(wget -qO- https://dl.akuity.io/akuity-cli/stable.txt); \
  fi && \
  echo "Using akuity version: $AKUITY_VERSION" && \
  wget -qO /usr/local/bin/akuity \
    "https://dl.akuity.io/akuity-cli/${AKUITY_VERSION}/linux/${ARCH}/akuity" && \
  chmod +x /usr/local/bin/akuity

####################################################################################################
# Final image
####################################################################################################
FROM $BASE_IMAGE AS kargo-creds-cron

ENV KARGO_USER_ID=999
ENV DEBIAN_FRONTEND=noninteractive

RUN groupadd -g $KARGO_USER_ID kargo && \
    useradd -r -u $KARGO_USER_ID -g kargo kargo && \
    mkdir -p /home/kargo && \
    chown -R kargo:0 /home/kargo && \
    chmod -R g=u /home/kargo && \
    apt-get update && apt-get install --no-install-recommends -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/
COPY --from=builder /usr/local/bin/akuity  /usr/local/bin/

# Expect your entrypoint and any helper scripts in src/*.sh
COPY --chown=root:root src/*.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh

WORKDIR /home/kargo

USER kargo

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
