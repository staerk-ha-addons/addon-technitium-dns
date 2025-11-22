# hadolint global ignore=DL3006,DL3008,SC1091,SC2039,SC3009

# Base image for Home Assistant add-ons
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:9.1.0

# ============================================================================
# BUILD STAGE
# ============================================================================
# hadolint ignore=DL3006
FROM ${BUILD_FROM} AS build

# Version configuration
ARG DNS_SERVER_VERSION=v14.1.0
ARG DNS_LIBRARY_VERSION=dns-server-${DNS_SERVER_VERSION}
ARG DOTNET_SDK_VERSION=9.0

# .NET environment settings
ENV DOTNET_ROOT=/usr/share/dotnet
ENV DOTNET_NOLOGO=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_EnableDiagnostics=0
ENV PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"

# Set up build workspace
WORKDIR /build/

# Install build dependencies and .NET SDK
# Then clone and build the Technitium DNS Server
# https://learn.microsoft.com/en-us/dotnet/core/install/linux-scripted-manual#scripted-install
# https://learn.microsoft.com/en-us/dotnet/core/install/linux-debian?tabs=dotnet8#dependencies
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/build.md
# hadolint ignore=DL3008,SC2039
RUN source /etc/os-release \
    # Add Microsoft package repository
    && curl -sSL -O "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    # Install required packages
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    git \
    libmsquic \
    libc6 \
    libgcc-s1 \
    libgssapi-krb5-2 \
    libicu76 \
    libssl3 \
    libstdc++6 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    # Install .NET SDK for building
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && bash dotnet-install.sh --channel "${DOTNET_SDK_VERSION}" --install-dir $DOTNET_ROOT \
    # Clone Technitium repositories
    && git clone --branch "${DNS_LIBRARY_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/TechnitiumLibrary.git TechnitiumLibrary \
    && git clone --branch "${DNS_SERVER_VERSION}" --depth 1 https://github.com/TechnitiumSoftware/DnsServer.git DnsServer \
    # Build required libraries
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.ByteTree/TechnitiumLibrary.ByteTree.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Net/TechnitiumLibrary.Net.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Security.OTP/TechnitiumLibrary.Security.OTP.csproj -c Release \
    # Build and publish DNS server application
    && dotnet publish DnsServer/DnsServerApp/DnsServerApp.csproj -c Release \
    # Copy built application to final directory
    && mkdir -p /opt/technitium/dns \
    && cp -r DnsServer/DnsServerApp/bin/Release/publish/* /opt/technitium/dns \
    # Clean up build artifacts and temporary files
    && rm -fr \
    /build/ \
    /root/.cache \
    /tmp/* \
    /var/{cache,log}/* \
    /var/lib/apt/lists/*

# ============================================================================
# INSTALL STAGE
# ============================================================================
# hadolint ignore=DL3006
FROM ${BUILD_FROM} AS install

# Configure .NET runtime environment
ARG DOTNET_SDK_VERSION=9.0
ENV DOTNET_ROOT=/usr/share/dotnet
ENV DOTNET_NOLOGO=1
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_EnableDiagnostics=0
ENV PATH="$PATH:$DOTNET_ROOT"

# Install runtime dependencies and .NET runtime
# hadolint ignore=DL3008,SC1091
RUN source /etc/os-release \
    # Add Microsoft package repository
    && curl -sSL -O "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    # Install required packages
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    openssl \
    inotify-tools \
    libmsquic \
    libc6 \
    libgcc-s1 \
    libgssapi-krb5-2 \
    libicu76 \
    libssl3 \
    libstdc++6 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    # Install only ASP.NET Core runtime (not the full SDK)
    && curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
    && bash dotnet-install.sh --channel "${DOTNET_SDK_VERSION}" --runtime aspnetcore --install-dir $DOTNET_ROOT \
    && rm -f dotnet-install.sh

# Copy DNS server application from build stage
COPY --from=build /opt/technitium/dns /opt/technitium/dns/

# ============================================================================
# RUNTIME STAGE
# ============================================================================
FROM install AS runtime

# Copy Home Assistant add-on files
COPY rootfs /
RUN chmod +x /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish

# Add build arguments for labels
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Add standard Home Assistant labels
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
    org.opencontainers.image.url="https://github.com/staerk-ha-addons/repository" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.url.bugs="https://github.com/${BUILD_REPOSITORY}/issues" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
