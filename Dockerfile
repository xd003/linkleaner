# syntax=docker/dockerfile:1
# Cross-compiles on the build host's native arch (no QEMU emulation of rustc),
# then copies the binary into a distroless image for the target arch.
FROM --platform=$BUILDPLATFORM rust:1-bookworm AS builder
ARG TARGETARCH
ARG BUILDARCH
WORKDIR /src

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) triple=x86_64-unknown-linux-gnu; gnu=x86_64-linux-gnu; pkg=gcc-x86-64-linux-gnu ;; \
      arm64) triple=aarch64-unknown-linux-gnu; gnu=aarch64-linux-gnu; pkg=gcc-aarch64-linux-gnu ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    echo "$triple" > /rust-target; \
    if [ "$TARGETARCH" != "$BUILDARCH" ]; then \
      apt-get update; \
      apt-get install -y --no-install-recommends "$pkg" "libc6-dev-${TARGETARCH}-cross"; \
      rm -rf /var/lib/apt/lists/*; \
      env_triple=$(echo "$triple" | tr 'a-z-' 'A-Z_'); \
      printf 'export CARGO_TARGET_%s_LINKER=%s-gcc\nexport CC_%s=%s-gcc\n' \
        "$env_triple" "$gnu" "$(echo "$triple" | tr '-' '_')" "$gnu" > /cross-env; \
    else \
      : > /cross-env; \
    fi

COPY rust-toolchain.toml ./
RUN rustup toolchain install && rustup target add "$(cat /rust-target)"

COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target,id=linkleaner-target-${TARGETARCH} \
    set -eux; \
    . /cross-env; \
    target=$(cat /rust-target); \
    cargo build --release --locked --target "$target"; \
    cp "target/$target/release/linkleaner" /linkleaner

FROM gcr.io/distroless/cc-debian12:nonroot
COPY --from=builder /linkleaner /usr/local/bin/linkleaner
ENTRYPOINT ["/usr/local/bin/linkleaner"]
