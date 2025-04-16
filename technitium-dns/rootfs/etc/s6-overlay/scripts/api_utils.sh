#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# API Utilities for Technitium DNS Server
#
# This module provides functions for interacting with the Technitium DNS Server
# API, including authentication, token management, and DNS configuration.
# ==============================================================================

if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

# -----------------------------------------------------------------------------
# Environment Variable Check
# -----------------------------------------------------------------------------
# Ensure required environment variables are set before proceeding
required_env_vars=("ADDON_API_SERVER" "ADDON_TOKEN_NAME" "ADDON_TOKEN_FILE" "ADDON_LOCK_FILE" "ADDON_DOMAIN")

for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        bashio::log.error "api_utils: Required environment variable ${var} is not set!"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Input Validation Functions
# -----------------------------------------------------------------------------
# Validate JSON response from API
validate_response() {
    local response="${1}"
    if [[ -z "${response}" ]]; then
        bashio::log.debug "api_utils: Empty response received"
        return 1
    fi

    if ! echo "${response}" | jq . >/dev/null 2>&1; then
        bashio::log.debug "api_utils: Invalid JSON response"
        return 1
    fi
    return 0
}

# Check that required parameters are provided for API calls
check_required_params() {
    local endpoint="${1}"
    local method="${2}"

    if [[ -z "${endpoint}" ]]; then
        bashio::log.debug "api_utils: Missing API endpoint"
        return 1
    fi

    if [[ ! "${method}" =~ ^(GET|POST)$ ]]; then
        bashio::log.debug "api_utils: Invalid HTTP method: ${method}"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Security Functions
# -----------------------------------------------------------------------------
# Encrypt API token for secure storage
encrypt_token() {
    local token="${1}"
    echo "${token}" | openssl enc -aes-256-cbc -pbkdf2 -a -salt -pass pass:"${ADDON_TOKEN_NAME}" 2>/dev/null
}

# Decrypt previously stored API token
decrypt_token() {
    local encrypted="${1}"
    echo "${encrypted}" | openssl enc -aes-256-cbc -pbkdf2 -a -d -salt -pass pass:"${ADDON_TOKEN_NAME}" 2>/dev/null
}

# Redact sensitive information from URLs for logging
redact_url() {
    local url="${1}"
    local redacted_url

    # Replace token and password values with REDACTED
    redacted_url=$(echo "${url}" | sed -E 's/([?&])(token|pass)=[^&]*/\1\2=REDACTED/g')

    echo "${redacted_url}"
}

# -----------------------------------------------------------------------------
# File Lock Management
# -----------------------------------------------------------------------------
# Create a directory-based lock to ensure atomic operations
acquire_lock() {
    local max_attempts=30
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if mkdir "${ADDON_LOCK_FILE}" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done

    bashio::log.warning "api_utils: Could not acquire lock after ${max_attempts} attempts"
    return 1
}

# Remove the directory lock
release_lock() {
    if ! rm -rf "${ADDON_LOCK_FILE}"; then
        bashio::log.warning "api_utils: Failed to release lock"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Token Management
# -----------------------------------------------------------------------------
# Save API token to encrypted storage
save_token() {
    local token="${1}"

    if [[ -z "${token}" ]]; then
        bashio::log.debug "api_utils: Cannot save empty token"
        return 1
    fi

    if acquire_lock; then
        encrypt_token "${token}" >"${ADDON_TOKEN_FILE}"
        chmod 600 "${ADDON_TOKEN_FILE}"
        local status=$?
        release_lock

        if [[ ${status} -eq 0 ]]; then
            bashio::log.debug "api_utils: API token encrypted and saved"
            return 0
        else
            bashio::log.warning "api_utils: Failed to save encrypted token"
            return 1
        fi
    fi

    bashio::log.warning "api_utils: Failed to acquire lock for saving token"
    return 1
}

# Load and decrypt the saved API token
load_saved_token() {
    if [[ ! -f "${ADDON_TOKEN_FILE}" ]]; then
        bashio::log.debug "api_utils: No saved token file exists"
        return 1
    fi

    if ! acquire_lock; then
        bashio::log.warning "api_utils: Failed to acquire lock for loading token"
        return 1
    fi

    local encrypted_token
    local saved_token
    encrypted_token=$(cat "${ADDON_TOKEN_FILE}")
    saved_token=$(decrypt_token "${encrypted_token}")
    release_lock

    if [[ -z "${saved_token}" ]]; then
        bashio::log.warning "api_utils: Failed to decrypt token"

        # Clean up invalid token file
        if acquire_lock; then
            rm -f "${ADDON_TOKEN_FILE}"
            release_lock
            bashio::log.debug "api_utils: Removed invalid token file"
        fi

        return 1
    fi

    echo "${saved_token}"
    bashio::log.debug "api_utils: Successfully loaded saved API token"
    return 0
}

# Get authentication token, creating one if needed
# shellcheck disable=SC2120
get_auth_token() {
    local username="${1:-admin}"
    local password="${2:-admin}"
    local token
    local max_retries=3
    local retry=0
    local response

    # Try to load existing token first
    if token=$(load_saved_token); then
        bashio::log.debug "api_utils: Using saved token"
        echo "${token}"
        return 0
    fi

    bashio::log.info "api_utils: Creating new API token..."

    while ((retry < max_retries)); do
        # Create permanent token - preferred method
        bashio::log.debug "api_utils: Attempting token creation (attempt ${retry})"
        if response=$(make_direct_call "user/createToken?user=${username}&pass=${password}&tokenName=${ADDON_TOKEN_NAME}"); then
            token=$(echo "${response}" | jq -r '.token // empty')
            if [[ -n "${token}" ]]; then
                bashio::log.info "api_utils: API token created successfully"
                save_token "${token}"
                echo "${token}"
                return 0
            else
                bashio::log.warning "api_utils: API token creation failed - empty token (attempt ${retry})"
            fi
        else
            bashio::log.warning "api_utils: API token creation call failed (attempt ${retry})"
        fi

        # Fallback to standard login if token creation fails
        bashio::log.info "api_utils: API token creation failed, trying standard login..."
        if response=$(make_direct_call "user/login?user=${username}&pass=${password}&includeInfo=true"); then
            token=$(echo "${response}" | jq -r '.token // empty')
            if [[ -n "${token}" ]]; then
                bashio::log.debug "api_utils: Authentication successful using standard login"
                echo "${token}"
                return 0
            fi
        fi

        ((retry++))
        if ((retry < max_retries)); then
            bashio::log.warning "api_utils: Authentication attempt ${retry} failed, retrying in 2s..."
            sleep 2
        fi
    done

    bashio::log.error "api_utils: Authentication failed after ${max_retries} attempts"
    return 1
}

# -----------------------------------------------------------------------------
# API Communication
# -----------------------------------------------------------------------------
# Make a direct API call without authentication
make_direct_call() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"

    # Validate input parameters
    if ! check_required_params "${endpoint}" "${method}"; then
        return 1
    fi

    # Ensure API server has proper protocol prefix
    local api_server="${ADDON_API_SERVER}"
    if [[ ! "${api_server}" =~ ^https?:// ]]; then
        api_server="http://${api_server}"
    fi

    # Fix the URL construction
    local url="${api_server}/api/${endpoint}"
    local safe_url
    safe_url=$(redact_url "${url}")

    bashio::log.debug "api_utils: Using API URL: ${safe_url}"

    # Build curl command with appropriate options
    local curl_cmd="curl -s --connect-timeout 10"

    if [[ "${method}" = "POST" ]]; then
        curl_cmd="${curl_cmd} -X POST -H 'Content-Type: application/json' -d '${data}'"
        bashio::log.trace "api_utils: Making Direct POST to: ${safe_url}"
        bashio::log.trace "api_utils: POST data: ${data}"
    else
        bashio::log.trace "api_utils: Making Direct GET to: ${safe_url}"
    fi

    # Make the API call and capture response
    local response
    bashio::log.debug "api_utils: Executing: ${curl_cmd} '${safe_url}'"
    response=$(eval "${curl_cmd} '${url}'")
    local status=$?

    # Log more details on failure
    if [[ ${status} -ne 0 ]]; then
        bashio::log.warning "api_utils: API call failed with curl exit code: ${status}"
        bashio::log.debug "api_utils: Curl error details: $(curl -s --version | head -n1)"
    fi

    # Validate JSON response if successful
    if [[ ${status} -eq 0 && -n "${response}" ]]; then
        if ! validate_response "${response}"; then
            bashio::log.warning "api_utils: Invalid response from API"
            return 1
        fi
    fi

    echo "${response}"
    return "${status}"
}

# Make an authenticated API call with retry logic
make_api_call() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"
    local max_attempts=30
    local wait_time=2
    local attempt=1
    local token

    # Get authentication token
    token=$(get_auth_token)

    # Validate input parameters
    if ! check_required_params "${endpoint}" "${method}"; then
        return 1
    fi

    bashio::log.debug "api_utils: === API Call Start ==="
    bashio::log.debug "api_utils: Endpoint: ${endpoint}"
    bashio::log.debug "api_utils: Method: ${method}"
    # Log data if available (for debugging)
    [[ -n "${data}" ]] && bashio::log.debug "api_utils: Data: \n $(echo "${data}" | jq . || true)"

    # Retry loop for API calls
    while [[ ${attempt} -le ${max_attempts} ]]; do
        bashio::log.debug "api_utils: Attempt ${attempt}/${max_attempts}"

        # Construct endpoint with token if needed
        local api_endpoint="${endpoint}"
        if [[ -n "${token}" ]]; then
            if [[ "${endpoint}" == *"?"* ]]; then
                api_endpoint="${endpoint}&token=${token}"
            else
                api_endpoint="${endpoint}?token=${token}"
            fi
            bashio::log.trace "api_utils: Added auth token to request"
        fi

        # Make the API call
        local response
        response=$(make_direct_call "${api_endpoint}" "${method}" "${data}")
        local call_status=$?

        if [[ ${call_status} -eq 0 ]]; then
            # Validate response before processing
            if ! validate_response "${response}"; then
                bashio::log.warning "api_utils: Invalid response format"
                return 1
            fi

            bashio::log.debug "api_utils: API call successful"

            # Format and log response
            local formatted_response
            if echo "${response}" | jq . >/dev/null 2>&1; then
                formatted_response=$(echo "${response}" | jq .)
                bashio::log.trace "api_utils: ${formatted_response}"
            else
                bashio::log.trace "api_utils: ${response}"
            fi

            # Ensure logging output is complete before returning
            bashio::log.debug "api_utils: === API Call End ==="
            echo "${response}"
            return 0
        fi

        bashio::log.debug "api_utils: API call failed (attempt ${attempt}/${max_attempts}), retrying in ${wait_time}s..."
        sleep "${wait_time}"
        attempt=$((attempt + 1))
    done

    bashio::log.error "api_utils: Failed to connect to API after ${max_attempts} attempts"
    bashio::log.debug "api_utils: === API Call End ==="
    return 1
}

# -----------------------------------------------------------------------------
# App Management
# -----------------------------------------------------------------------------
# Manage DNS apps (install, update) from Technitium DNS store
manage_dns_app() {
    local app_name="${1}"

    # Validate app name
    if [[ -z "${app_name}" ]]; then
        bashio::log.warning "api_utils: App name is required"
        return 1
    fi

    bashio::log.info "api_utils: Managing DNS app: ${app_name}"

    # Get store app info and validate response
    local store_info
    if ! store_info=$(make_api_call "apps/listStoreApps" "GET") ||
        ! validate_response "${store_info}"; then
        bashio::log.warning "api_utils: Failed to get valid store apps list"
        return 1
    fi

    # Find app in store
    local app_details
    app_details=$(echo "${store_info}" | jq -r --arg name "${app_name}" '.response.storeApps[] |
        select(.name == $name) | {
            version: .version,
            url: .url,
            name: .name
        }')

    if [[ -z "${app_details}" ]]; then
        bashio::log.warning "api_utils: App '${app_name}' not found in store"
        return 1
    fi

    # Extract version and encoded name and URLs
    local store_version
    local encoded_url
    local encoded_name
    store_version=$(echo "${app_details}" | jq -r '.version')
    encoded_url=$(echo "${app_details}" | jq -r '.url | @uri')
    encoded_name=$(echo "${app_details}" | jq -r '.name | @uri')

    bashio::log.info "api_utils: Found ${app_name} version ${store_version} in store"

    # Check if app is installed
    local local_info
    if ! local_info=$(make_api_call "apps/list" "GET"); then
        bashio::log.warning "api_utils: Failed to get local apps list"
        return 1
    fi

    # Check if app is installed and get version
    local local_version
    local_version=$(echo "${local_info}" | jq -r --arg name "${app_name}" '.response.apps[] |
        select(.name == $name) | .version // empty')

    # Install or update as needed
    if [[ -z "${local_version}" ]]; then
        bashio::log.info "api_utils: Installing ${app_name} v${store_version}..."
        if make_api_call "apps/downloadAndInstall?name=${encoded_name}&url=${encoded_url}" "GET" >/dev/null; then
            bashio::log.info "api_utils: ${app_name} installed successfully"
            return 0
        else
            bashio::log.warning "api_utils: Failed to install ${app_name}"
            return 1
        fi
    elif [[ "${local_version}" != "${store_version}" ]]; then
        bashio::log.info "api_utils: Updating ${app_name} from v${local_version} to v${store_version}..."
        if make_api_call "apps/downloadAndUpdate?url=${encoded_url}" "GET" >/dev/null; then
            bashio::log.info "api_utils: ${app_name} updated successfully"
            return 0
        else
            bashio::log.warning "api_utils: Failed to update ${app_name}"
            return 1
        fi
    else
        bashio::log.debug "api_utils: ${app_name} is up to date (v${local_version})"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
    if [[ -d "${ADDON_LOCK_FILE}" ]]; then
        rm -rf "${ADDON_LOCK_FILE}"
    fi
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# API Documentation References
# -----------------------------------------------------------------------------
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#login
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#create-api-token
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#set-dns-settings
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#list-apps
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#list-store-apps
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#download-and-install-app
# https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md#download-and-update-app
