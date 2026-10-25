# syntax=docker/dockerfile:1

ARG FLUTTER_VERSION=3.44.8
ARG RUST_VERSION=1.98
ARG DEBIAN_VERSION=trixie
ARG ALPINE_VERSION=3.24

# --- Flutter web build -------------------------------------------------------
# Stays on Debian: Flutter's SDK needs glibc. Only the built files are kept.
FROM debian:${DEBIAN_VERSION}-slim AS web
ARG FLUTTER_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
# Flutter discourages running as root (and root's tar trips over archive
# ownership under rootless podman), so build as a regular user.
RUN useradd --create-home build && mkdir /opt/flutter /src && chown build /opt/flutter /src
USER build
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --no-cli-animations \
    && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos --no-fuchsia

WORKDIR /src
COPY --chown=build app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY --chown=build app/ ./
RUN flutter build web --release

# --- Rust server build -------------------------------------------------------
FROM rust:${RUST_VERSION}-alpine${ALPINE_VERSION} AS server
# musl-dev is needed to link, and to compile the bundled SQLite.
RUN apk add --no-cache musl-dev
WORKDIR /src
# Build dependencies on their own first so they're cached between code changes.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs && touch src/lib.rs \
    && cargo build --release --locked \
    && rm -rf src
COPY migrations migrations
COPY src src
# Make sure cargo sees the real sources as newer than the placeholder build.
RUN touch src/main.rs src/lib.rs && cargo build --release --locked

# --- Runtime image -----------------------------------------------------------
FROM alpine:${ALPINE_VERSION}
RUN adduser -S -D -H -u 10001 -h /data todos \
    && mkdir /data && chown todos /data
COPY --from=server /src/target/release/todos /usr/local/bin/todos
COPY --from=web /src/build/web /srv/web

ENV BIND_ADDR=0.0.0.0:3000 \
    DATABASE_URL=sqlite:///data/todos.db \
    STATIC_DIR=/srv/web
VOLUME /data
USER todos
EXPOSE 3000
CMD ["todos"]
