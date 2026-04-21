FROM rust:nightly-bookworm AS builder

WORKDIR /app

COPY Cargo.toml Cargo.lock rust-toolchain.toml ./
COPY src ./src

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/app/target \
    cargo build --locked --release && \
    cp target/release/linkleaner /tmp/linkleaner

FROM debian:bookworm-slim AS runtime

RUN apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --create-home --uid 10001 --shell /usr/sbin/nologin linkleaner

WORKDIR /app

COPY --from=builder /tmp/linkleaner /usr/local/bin/linkleaner

USER linkleaner

ENTRYPOINT ["/usr/local/bin/linkleaner"]
