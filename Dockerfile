# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bookworm-20241105-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.18.4-erlang-27.2.2-debian-bookworm-20241105-slim
#
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.2.2
ARG DEBIAN_VERSION=bookworm-20241105-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
# Note: consider adding a .dockerignore file to exclude unnecessary files from the build context
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    ca-certificates \
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@10.9.2 \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# Copy priv for migrations/seeds that might be needed during compile
COPY priv priv

# Copy application code
COPY lib lib

# Copy and build assets
COPY assets assets
RUN cd assets && npm ci --prefer-offline --no-audit --progress=false && cd ..

# Compile the application and build release
RUN mix compile && \
    mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy release configuration and build release
COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# Install runtime dependencies including tini for proper signal handling
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    tini \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    # these last two required for Panic.Workers.Archiver
    ffmpeg \
    imagemagick \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/panic ./

USER nobody

# Use tini as PID 1 to handle signals properly and reap zombie processes
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/app/bin/server"]
