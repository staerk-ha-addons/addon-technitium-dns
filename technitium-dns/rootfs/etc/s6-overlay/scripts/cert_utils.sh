#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Certificate Management Utilities for Technitium DNS Server
#
# This module provides functions to manage SSL certificates for the DNS server,
# including validation, generation of self-signed certificates, and conversion
# to PKCS12 format required by the Technitium DNS Server.
# ==============================================================================
set -o nounset -o errexit -o pipefail

# Enable debug logging if DEBUG environment variable is set to true
if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

bashio::log.trace "cert_utils: Initializing certificate management utilities"

# Load certificate utility modules
# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils/core.sh
source /etc/s6-overlay/scripts/cert_utils/core.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils/openssl.sh
source /etc/s6-overlay/scripts/cert_utils/openssl.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils/validation.sh
source /etc/s6-overlay/scripts/cert_utils/validation.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils/generation.sh
source /etc/s6-overlay/scripts/cert_utils/generation.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils/pkcs12.sh
source /etc/s6-overlay/scripts/cert_utils/pkcs12.sh
