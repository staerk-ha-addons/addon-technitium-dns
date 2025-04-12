ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.8.1
FROM ${BUILD_FROM}

ARG DNS_LIBRARY_VERSION=master
ARG DNS_SERVER_VERSION=master
ARG DOTNET_SDK_VERSION=8.0
ENV DNS_LIBRARY_VERSION=${DNS_LIBRARY_VERSION}
ENV DNS_SERVER_VERSION=${DNS_SERVER_VERSION}
ENV DOTNET_SDK_VERSION=${DOTNET_SDK_VERSION}
ENV DOTNET_ROOT=/usr/share/dotnet
ENV DOTNET_NOLOGO=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"


SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /build/
RUN source /etc/os-release \
    && curl -sSL -O "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends git libmsquic libc6 libgcc-s1 libgssapi-krb5-2 libicu72 libssl3 libstdc++6 zlib1g \
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && bash dotnet-install.sh --channel "${DOTNET_SDK_VERSION}" --install-dir $DOTNET_ROOT \
    && git clone --branch "${DNS_LIBRARY_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/TechnitiumLibrary.git TechnitiumLibrary \
    && git clone --branch "${DNS_SERVER_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/DnsServer.git DnsServer \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.ByteTree/TechnitiumLibrary.ByteTree.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Net/TechnitiumLibrary.Net.csproj -c Release \
    && dotnet publish DnsServer/DnsServerApp/DnsServerApp.csproj -c Release \
    && mkdir -p /opt/technitium/dns \
    && cp -r DnsServer/DnsServerApp/bin/Release/publish/* /opt/technitium/dns \
    && rm -fr \
    /build/ \
    /root/.cache \
    /tmp/* \
    /var/{cache,log}/* \
    /var/lib/apt/lists/*

COPY rootfs /

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Jeppe Stærk <jeppe@staerk.dev>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Staerk Home Assistant Add-ons" \
    org.opencontainers.image.authors="Jeppe Stærk <jeppe@staerk.dev>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://staerk.dev" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
