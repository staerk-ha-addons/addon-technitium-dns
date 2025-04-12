ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.8.1
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
# https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script
ARG DOTNET_SDK_VERSION=8.0
ENV DOTNET_SDK_VERSION=${DOTNET_SDK_VERSION}
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"
RUN source /etc/os-release \
    && curl -sSL -O "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends git libmsquic libc6 libgcc-s1 libgssapi-krb5-2 libicu72 libssl3 libstdc++6 zlib1g \
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && bash dotnet-install.sh --channel "${DOTNET_SDK_VERSION}" --install-dir $DOTNET_ROOT \
    && rm dotnet-install.sh

# Set working directory
WORKDIR /build/

# Clone Technitium DNS Server
ARG DNS_LIBRARY_VERSION=master
ARG DNS_SERVER_VERSION=master
ENV DNS_LIBRARY_VERSION=${DNS_LIBRARY_VERSION}
ENV DNS_SERVER_VERSION=${DNS_SERVER_VERSION}
RUN git clone --branch "${DNS_LIBRARY_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/TechnitiumLibrary.git TechnitiumLibrary
RUN git clone --branch "${DNS_SERVER_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/DnsServer.git DnsServer

# Build Technitium DNS Server
ENV DOTNET_NOLOGO=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN dotnet build TechnitiumLibrary/TechnitiumLibrary.ByteTree/TechnitiumLibrary.ByteTree.csproj -c Release
RUN dotnet build TechnitiumLibrary/TechnitiumLibrary.Net/TechnitiumLibrary.Net.csproj -c Release
RUN dotnet publish DnsServer/DnsServerApp/DnsServerApp.csproj -c Release

# Create directory structure in container
RUN mkdir -p /opt/technitium/dns

# Copy DnsServer application into container directory
RUN cp -r DnsServer/DnsServerApp/bin/Release/publish/* /opt/technitium/dns

# Cleanup build files
RUN rm -rf /build/

# Copy the root filesystem to the container
COPY rootfs /

# Build arguments
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Jeppe Stærk <jeppe@staerk.dev>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Staerk's Home Assistant Add-ons" \
    org.opencontainers.image.authors="Jeppe Stærk <jeppe@staerk.dev>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://staerk.dev" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}