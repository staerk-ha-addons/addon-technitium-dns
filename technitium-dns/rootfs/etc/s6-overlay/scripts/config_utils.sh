#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Configuration Utilities for Technitium DNS Server
#
# This module provides functions for configuring and setting up the Technitium
# DNS Server, including hostname resolution and forwarder configuration.
# ==============================================================================
set -o nounset -o errexit -o pipefail

# Enable debug logging if DEBUG environment variable is set to true
if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

bashio::log.trace "config_utils: Initializing configuration utilities"

# Load all configuration utility modules
# shellcheck source=rootfs/etc/s6-overlay/scripts/config_utils/system.sh
source /etc/s6-overlay/scripts/config_utils/system.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/config_utils/domain.sh
source /etc/s6-overlay/scripts/config_utils/domain.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/config_utils/certificates.sh
source /etc/s6-overlay/scripts/config_utils/certificates.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/config_utils/forwarders.sh
source /etc/s6-overlay/scripts/config_utils/forwarders.sh
