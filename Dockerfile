FROM debian:stretch-slim AS zip_downloader
LABEL maintainer="Michael Lynch <michael@mtlynch.io>"

ARG SIA_VERSION="1.4.2.1"
ARG SIA_PACKAGE="Sia-v${SIA_VERSION}-linux-amd64"
ARG SIA_ZIP="${SIA_PACKAGE}.zip"
ARG SIA_RELEASE="https://sia.tech/static/releases/${SIA_ZIP}"

RUN apt-get update
RUN apt-get install -y \
      wget \
      unzip

RUN wget "$SIA_RELEASE" && \
      mkdir /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siac" -d /sia && \
      unzip -j "$SIA_ZIP" "${SIA_PACKAGE}/siad" -d /sia

FROM debian:stretch-slim
ARG SIA_DIR="/sia"
ARG SIA_DATA_DIR="/sia-data"

COPY --from=zip_downloader /sia/siac "${SIA_DIR}/siac"
COPY --from=zip_downloader /sia/siad "${SIA_DIR}/siad"

RUN apt-get update
RUN apt-get install --yes \
      bash \
      socat \
      sudo

# Workaround for backwards compatibility with old images, which hardcoded the
# Sia data directory as /mnt/sia. Creates a symbolic link so that any previous
# path references stored in the Sia host config still work.
RUN ln --symbolic "$SIA_DATA_DIR" /mnt/sia

# Information for Sia system account.
ARG SIA_USER="sia"
ARG SIA_GROUP="sia"
RUN set -uxe && \
    groupadd "$SIA_GROUP" && \
    useradd \
      --comment "Sia system account" \
      --home-dir "$SIA_DIR" \
      --create-home \
      --system \
      --gid "$SIA_GROUP" \
      "$SIA_USER"

EXPOSE 9980 9981 9982

WORKDIR "$SIA_DIR"

ENV SIA_USER="$SIA_USER"
ENV SIA_GROUP="$SIA_GROUP"
ENV SIA_DIR "$SIA_DIR"
ENV SIA_DATA_DIR "$SIA_DATA_DIR"
ENV SIA_MODULES gctwhr

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT set -uxe && \
      chown \
            --no-dereference \
            --recursive \
            "${SIA_USER}:${SIA_GROUP}" "$SIA_DATA_DIR" && \
      chown \
            --no-dereference \
            --recursive \
            "${SIA_USER}:${SIA_GROUP}" "$SIA_DIR" && \
      sudo -u "$SIA_USER" ./siad \
            --modules "$SIA_MODULES" \
            --sia-directory "$SIA_DATA_DIR" \
            --api-addr "localhost:8000"
