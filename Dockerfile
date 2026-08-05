# syntax=docker/dockerfile:1.7

# BuildKit runs the builder for the requested platform. For linux/arm64 this
# provides an aarch64 compiler and makes vcpkg use the arm64-linux triplet.
#==================== Build stage ====================
FROM --platform=$TARGETPLATFORM rust:1.90.0-bookworm AS builder

ARG TARGETARCH
RUN case "$TARGETARCH" in amd64|arm64) ;; *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; esac

RUN sed -i 's|http://deb.debian.org|https://mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/debian.sources

# Install vcpkg dependencies
RUN apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    git build-essential cmake make zip unzip tar curl \
    pkg-config autoconf automake libtool linux-libc-dev libgl1-mesa-dev \
 && rm -rf /var/lib/apt/lists/*

# Install vcpkg at the same baseline used by the manifest
WORKDIR /opt
RUN git clone https://github.com/microsoft/vcpkg.git && \
    cd vcpkg && \
    git checkout 84bab45d415d22042bd0b9081aea57f362da3f35 && \
    ./bootstrap-vcpkg.sh

# Install OpenGL related dependencies (as in GitHub workflow)
RUN apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    libgl1-mesa-dev libglu1-mesa-dev \
    libx11-dev libxrandr-dev libxi-dev libxxf86vm-dev \
 && rm -rf /var/lib/apt/lists/*

# Set environment variables for vcpkg
ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH=$VCPKG_ROOT:$PATH

# Copy source code
WORKDIR /app
COPY . .

# Build the project
ENV CARGO_TERM_COLOR=always
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/root/.cache/vcpkg/archives \
    --mount=type=cache,target=/opt/vcpkg/downloads \
    cargo build --release -vv

# File-only target for the bundle consumed by Java ProcessBuilder:
# docker buildx build --platform linux/arm64 --target bundle \
#   --output type=local,dest=dist/linux-arm64 .
FROM scratch AS bundle
COPY --from=builder /app/target/release/_3dtile /_3dtile
COPY --from=builder /app/target/release/gdal /gdal
COPY --from=builder /app/target/release/proj /proj
COPY --from=builder /app/target/release/osgPlugins-3.6.5 /osgPlugins-3.6.5

#==================== Runtime stage ====================
FROM --platform=$TARGETPLATFORM debian:bookworm-slim AS runtime

RUN sed -i 's|http://deb.debian.org|https://mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/debian.sources

RUN apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    libgl1 libx11-6 libxi6 libxrandr2 libstdc++6 \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /3dtiles
WORKDIR /3dtiles

# Copy executable and runtime data
COPY --from=builder /app/target/release/_3dtile /3dtiles/_3dtile
COPY --from=builder /app/target/release/gdal /3dtiles/gdal
COPY --from=builder /app/target/release/proj /3dtiles/proj
COPY --from=builder /app/target/release/osgPlugins-3.6.5 /3dtiles/osgPlugins-3.6.5

# Set environment variables for runtime
ENV OSG_LIBRARY_PATH=/3dtiles/osgPlugins-3.6.5
ENV GDAL_DATA=/3dtiles/gdal
ENV PROJ_DATA=/3dtiles/proj

WORKDIR /data
ENTRYPOINT ["/3dtiles/_3dtile"]
CMD ["--help"]
