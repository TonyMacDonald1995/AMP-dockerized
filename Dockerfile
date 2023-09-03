FROM debian:12-slim
 
ARG TARGETPLATFORM # Set by Docker, see https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

ENV UID=1000
ENV GID=1000
ENV TZ=Etc/UTC
ENV PORT=8080
ENV USERNAME=admin
ENV PASSWORD=password
ENV IPBINDING=0.0.0.0

ENV AMP_AUTO_UPDATE=true
ENV AMP_LICENCE=notset
ENV AMP_MODULE=ADS
ENV AMP_RELEASE_STREAM=Mainline
ENV AMP_SUPPORT_LEVEL=UNSUPPORTED
ENV AMP_SUPPORT_TOKEN=AST0/MTAD
ENV AMP_SUPPORT_TAGS="nosupport docker community unofficial unraid"
ENV AMP_SUPPORT_URL="https://github.com/MitchTalmadge/AMP-dockerized/"
ENV LD_LIBRARY_PATH="./:/opt/cubecoders/amp/:/AMP/"

ARG DEBIAN_FRONTEND=noninteractive

# Initialize
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    jq \
    sed \
    tzdata \
    wget && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Configure Locales
RUN apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8


# Install Mono
RUN apt-get update && \
    apt-get install -y \
    dirmngr \
    ca-certificates \
    gnupg && \
    gpg --homedir /tmp --no-default-keyring --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/debian stable-buster main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
    apt-get update && \
    apt-get install -y mono-devel && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Declare and install AMP dependencies

ARG AMPDEPS="\
    # Dependencies for AMP:
    apt-transport-https \
    tmux \
    git \
    git-lfs \
    socat \
    unzip \
    iputils-ping \
    procps \
    numactl \
    gnupg \
    locales \
    software-properties-common \
    libc++-dev \
    coreutils \
    libsqlite3-0 \
    curl \
    gdb \
    xz-utils \
    bzip2 \
    libzstd1 \
    libgdiplus \
    libc6 \
    libatomic1 \
    libpulse-dev \
    liblua5.3-0"

ARG SRCDSDEPS="\
    # Dependencies for srcds (TF2, GMod, ...)
    lib32gcc-s1 \
    lib32stdc++6 \
    lib32z1 \
    libbz2-1.0:i386 \
    libcurl3-gnutls:i386 \
    libcurl4 \
    libncurses5:i386 \
    libsdl2-2.0-0 \
    libsdl2-2.0-0:i386 \
    libtinfo5:i386"

ARG WINEXVFB="\
    # Needed for games that require Wine and Xvfb
    xvfb \
    wine \
    wine32 \
    wine64 \
    wine-binfmt \
    python3 \
    winbind \
    libwine \
    libwine:i386 \
    fonts-wine \
    xauth"

ARG FACDEPS="\
    # Dependencies for Factorio:
    xz-utils"

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        dpkg --add-architecture aarch64 && \
        apt-get update && \
        apt-get install -y \
        $AMPDEPS \
        $FACDEPS; \
    else \ 
        dpkg --add-architecture i386 && \
        apt-get update && \
        apt-get install -y \
        $AMPDEPS \
        $SRCDSDEPS \
        $WINEXVFB \
        $FACDEPS; \
    fi && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Install Adoptium JDK
RUN wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor > /usr/share/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-8-jdk temurin-11-jdk temurin-17-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Manually install ampinstmgr by extracting it from the deb package.
# Docker doesn't have systemctl and other things that AMP's deb postinst expects,
# so we can't use apt to install ampinstmgr.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    dirmngr \
    apt-transport-https

# Add CubeCoders repository and key
RUN wget -qO - http://repo.cubecoders.com/archive.key | gpg --dearmor > /etc/apt/trusted.gpg.d/cubecoders-archive-keyring.gpg && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        apt-add-repository "deb http://repo.cubecoders.com/aarch64 debian/"; \
    else \
        apt-add-repository "deb http://repo.cubecoders.com/ debian/"; \
    fi && \
    apt-get update && \
    # Just download (don't actually install) ampinstmgr
    apt-get install -y --no-install-recommends --download-only ampinstmgr && \
    # Extract ampinstmgr from downloaded package
    mkdir -p /tmp/ampinstmgr && \
    dpkg-deb -x /var/cache/apt/archives/ampinstmgr_*.deb /tmp/ampinstmgr && \
    mv /tmp/ampinstmgr/opt/cubecoders/amp/ampinstmgr /usr/local/bin/ampinstmgr && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Set up environment
COPY entrypoint /opt/entrypoint
RUN chmod -R +x /opt/entrypoint

VOLUME ["/home/amp/.ampdata"]

ENTRYPOINT ["/opt/entrypoint/main.sh"]
