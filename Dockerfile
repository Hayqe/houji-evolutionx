FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Android build dependencies for Ubuntu 24.04 (AOSP + LineageOS/EvolutionX)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    ccache \
    curl \
    erofs-utils \
    erofsfuse \
    flex \
    fuse \
    fuse2fs \
    g++-multilib \
    gcc-multilib \
    git \
    git-lfs \
    gnupg \
    gperf \
    imagemagick \
    lib32ncurses-dev \
    lib32readline-dev \
    lib32z1-dev \
    libc6-dev-i386 \
    libelf-dev \
    libgl1-mesa-dev \
    libncurses-dev \
    libsdl1.2-dev \
    libssl-dev \
    libx11-dev \
    libxml2 \
    libxml2-utils \
    lz4 \
    lzop \
    openjdk-17-jdk \
    pngcrush \
    python3 \
    python-is-python3 \
    rsync \
    schedtool \
    squashfs-tools \
    unzip \
    wget \
    xsltproc \
    zip \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install the repo tool
RUN curl -fsSL -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
    && chmod a+x /usr/local/bin/repo

# Ubuntu 24.04 ships a pre-existing 'ubuntu' user with uid 1000 / gid 1000,
# which matches the host user's uid/gid, so bind-mounted files keep ownership.
USER ubuntu
WORKDIR /src

RUN git config --global user.email "build@localhost" \
    && git config --global user.name "Build User" \
    && git config --global color.ui false

CMD ["bash"]
