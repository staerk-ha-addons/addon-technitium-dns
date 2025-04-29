#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# API Utilities for Technitium DNS Server
#
# This module provides functions for interacting with the Technitium DNS Server
# API, including authentication, token management, and DNS configuration.
# ==============================================================================
set -o nounset -o errexit -o pipefail

bashio::log.trace "api_utils: Initializing API utilities"

readonly DNS_API_TOKEN_NAME="ha-addon-token"
readonly DNS_API_TOKEN_FILE="/config/.${DNS_API_TOKEN_NAME}.enc"
readonly DNS_API_TOKEN_LOCK_FILE="/tmp/.${DNS_API_TOKEN_NAME}.lock"

# Source all API utility modules
# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/core.sh
source /etc/s6-overlay/scripts/utils/api_utils/core.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/validators.sh
source /etc/s6-overlay/scripts/utils/api_utils/validators.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/security.sh
source /etc/s6-overlay/scripts/utils/api_utils/security.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/token_manager.sh
source /etc/s6-overlay/scripts/utils/api_utils/token_manager.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/api_client.sh
source /etc/s6-overlay/scripts/utils/api_utils/api_client.sh

# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils/app_manager.sh
source /etc/s6-overlay/scripts/utils/api_utils/app_manager.sh

# Register cleanup function for script termination signals
trap api_cleanup EXIT INT TERM HUP
