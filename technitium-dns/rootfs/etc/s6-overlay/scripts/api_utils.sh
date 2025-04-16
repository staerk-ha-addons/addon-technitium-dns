#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# API Utilities for Technitium DNS Server
#
# This module provides functions for interacting with the Technitium DNS Server
# API, including authentication, token management, and DNS configuration.
# ==============================================================================

# -----------------------------------------------------------------------------
# Environment Variable Check
# -----------------------------------------------------------------------------
# Ensure required environment variables are set before proceeding
required_env_vars=("ADDON_API_SERVER" "ADDON_TOKEN_NAME" "ADDON_TOKEN_FILE" "ADDON_LOCK_FILE" "ADDON_HOSTNAME")

for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        bashio::log.error "Required environment variable ${var} is not set!"
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
        bashio::log.debug "Empty response received"
        return 1
    fi

    if ! echo "${response}" | jq . >/dev/null 2>&1; then
        bashio::log.debug "Invalid JSON response"
        return 1
    fi
    return 0
}

# Check that required parameters are provided for API calls
check_required_params() {
    local endpoint="${1}"
    local method="${2}"

    if [[ -z "${endpoint}" ]]; then
        bashio::log.debug "Missing API endpoint"
        return 1
    fi

    if [[ ! "${method}" =~ ^(GET|POST)$ ]]; then
        bashio::log.debug "Invalid HTTP method: ${method}"
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
    # Replace token and password values with REDACTED
    local redacted="${url//token=[^&]*\(&\|$\)/token=REDACTED\1}"
    redacted="${redacted//password=[^&]*\(&\|$\)/password=REDACTED\1}"
    echo "${redacted}"
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

    bashio::log.warning "Could not acquire lock after ${max_attempts} attempts"
    return 1
}

# Remove the directory lock
release_lock() {
    if ! rm -rf "${ADDON_LOCK_FILE}"; then
        bashio::log.warning "Failed to release lock"
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
        bashio::log.debug "Cannot save empty token"
        return 1
    fi

    if acquire_lock; then
        encrypt_token "${token}" >"${ADDON_TOKEN_FILE}"
        chmod 600 "${ADDON_TOKEN_FILE}"
        local status=$?
        release_lock

        if [[ ${status} -eq 0 ]]; then
            bashio::log.debug "API token encrypted and saved"
            return 0
        else
            bashio::log.warning "Failed to save encrypted token"
            return 1
        fi
    fi

    bashio::log.warning "Failed to acquire lock for saving token"
    return 1
}

# Load and decrypt the saved API token
load_saved_token() {
    if [[ ! -f "${ADDON_TOKEN_FILE}" ]]; then
        bashio::log.debug "No saved token file exists"
        return 1
    fi

    if ! acquire_lock; then
        bashio::log.warning "Failed to acquire lock for loading token"
        return 1
    fi

    local encrypted_token
    local saved_token
    encrypted_token=$(cat "${ADDON_TOKEN_FILE}")
    saved_token=$(decrypt_token "${encrypted_token}")
    release_lock

    if [[ -z "${saved_token}" ]]; then
        bashio::log.warning "Failed to decrypt token"

        # Clean up invalid token file
        if acquire_lock; then
            rm -f "${ADDON_TOKEN_FILE}"
            release_lock
            bashio::log.debug "Removed invalid token file"
        fi

        return 1
    fi

    echo "${saved_token}"
    bashio::log.debug "Successfully loaded saved API token"
    return 0
}

# Get authentication token, creating one if needed
# shellcheck disable=SC2120
get_auth_token() {
    local username="${1:-admin}"
    local password="${2:-admin}"
    local token

    # Try to load existing token first
    if token=$(load_saved_token); then
        echo "${token}"
        return 0
    fi

    bashio::log.info "Creating new API token..."

    # Create permanent token - preferred method
    if response=$(make_direct_call "user/createToken?user=${username}&pass=${password}&tokenName=${ADDON_TOKEN_NAME}"); then
        token=$(echo "${response}" | jq -r '.token // empty')
        if [[ -n "${token}" ]]; then
            save_token "${token}"
            echo "${token}"
            return 0
        fi
    fi

    # Fallback to standard login if token creation fails
    bashio::log.info "API token creation failed, falling back to standard login..."
    if response=$(make_direct_call "user/login?user=${username}&pass=${password}&includeInfo=true"); then
        token=$(echo "${response}" | jq -r '.token // empty')
        if [[ -n "${token}" ]]; then
            bashio::log.debug "Authentication successful using standard login"
            echo "${token}"
            return 0
        fi
    fi

    bashio::log.error "Authentication failed"
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

    local url="${ADDON_API_SERVER}/api/${endpoint}"
    local safe_url
    safe_url=$(redact_url "${url}")

    # Build curl command with appropriate options
    local curl_cmd="curl -s --connect-timeout 10"

    if [[ "${method}" = "POST" ]]; then
        curl_cmd="${curl_cmd} -X POST -H 'Content-Type: application/json' -d '${data}'"
        bashio::log.trace "Making Direct POST to: ${safe_url}"
        bashio::log.trace "POST data: ${data}"
    else
        bashio::log.trace "Making Direct GET to: ${safe_url}"
    fi

    # Make the API call and capture response
    local response
    response=$(eval "${curl_cmd} '${url}'")
    local status=$?

    # Validate JSON response if successful
    if [[ ${status} -eq 0 && -n "${response}" ]]; then
        if ! validate_response "${response}"; then
            bashio::log.warning "Invalid response from API"
            return 1
        fi
    fi

    # Parse and log response status
    if [[ ${status} -eq 0 ]]; then
        if [[ "${response}" == *"\"status\":\"Error\""* ]]; then
            local error_msg
            error_msg=$(echo "${response}" | sed -n 's/.*"errorMessage":"\([^"]*\)".*/\1/p')
            bashio::log.debug "API call failed with error: ${error_msg}"
        else
            bashio::log.trace "API call successful"
        fi
    else
        bashio::log.warning "API call failed with curl exit code: ${status}"
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

    bashio::log.debug "=== API Call Start ==="
    bashio::log.debug "Endpoint: ${endpoint}"
    bashio::log.debug "Method: ${method}"
    # Log data if available (for debugging)
    [[ -n "${data}" ]] && bashio::log.debug "Data: \n $(echo "${data}" | jq . || true)"

    # Retry loop for API calls
    while [[ ${attempt} -le ${max_attempts} ]]; do
        bashio::log.debug "Attempt ${attempt}/${max_attempts}"

        # Construct endpoint with token if needed
        local api_endpoint="${endpoint}"
        if [[ -n "${token}" ]]; then
            if [[ "${endpoint}" == *"?"* ]]; then
                api_endpoint="${endpoint}&token=${token}"
            else
                api_endpoint="${endpoint}?token=${token}"
            fi
            bashio::log.trace "Added auth token to request"
        fi

        # Make the API call
        local response
        response=$(make_direct_call "${api_endpoint}" "${method}" "${data}")
        local call_status=$?

        if [[ ${call_status} -eq 0 ]]; then
            # Validate response before processing
            if ! validate_response "${response}"; then
                bashio::log.warning "Invalid response format"
                return 1
            fi

            bashio::log.debug "API call successful"

            # Format and log response
            local formatted_response
            if echo "${response}" | jq . >/dev/null 2>&1; then
                formatted_response=$(echo "${response}" | jq .)
                bashio::log.trace "${formatted_response}"
            else
                bashio::log.trace "${response}"
            fi

            # Ensure logging output is complete before returning
            bashio::log.debug "=== API Call End ==="
            echo "${response}"
            return 0
        fi

        bashio::log.debug "API call failed (attempt ${attempt}/${max_attempts}), retrying in ${wait_time}s..."
        sleep "${wait_time}"
        attempt=$((attempt + 1))
    done

    bashio::log.error "Failed to connect to API after ${max_attempts} attempts"
    bashio::log.debug "=== API Call End ==="
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
        bashio::log.warning "App name is required"
        return 1
    fi

    bashio::log.info "Managing DNS app: ${app_name}"

    # Get store app info and validate response
    local store_info
    if ! store_info=$(make_api_call "apps/listStoreApps" "GET") ||
        ! validate_response "${store_info}"; then
        bashio::log.warning "Failed to get valid store apps list"
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
        bashio::log.warning "App '${app_name}' not found in store"
        return 1
    fi

    # Extract version and encoded name and URLs
    local store_version
    local encoded_url
    local encoded_name
    store_version=$(echo "${app_details}" | jq -r '.version')
    encoded_url=$(echo "${app_details}" | jq -r '.url | @uri')
    encoded_name=$(echo "${app_details}" | jq -r '.name | @uri')

    bashio::log.info "Found ${app_name} version ${store_version} in store"

    # Check if app is installed
    local local_info
    if ! local_info=$(make_api_call "apps/list" "GET"); then
        bashio::log.warning "Failed to get local apps list"
        return 1
    fi

    # Check if app is installed and get version
    local local_version
    local_version=$(echo "${local_info}" | jq -r --arg name "${app_name}" '.response.apps[] |
        select(.name == $name) | .version // empty')

    # Install or update as needed
    if [[ -z "${local_version}" ]]; then
        bashio::log.info "Installing ${app_name} v${store_version}..."
        if make_api_call "apps/downloadAndInstall?name=${encoded_name}&url=${encoded_url}" "GET" >/dev/null; then
            bashio::log.info "${app_name} installed successfully"
            return 0
        else
            bashio::log.warning "Failed to install ${app_name}"
            return 1
        fi
    elif [[ "${local_version}" != "${store_version}" ]]; then
        bashio::log.info "Updating ${app_name} from v${local_version} to v${store_version}..."
        if make_api_call "apps/downloadAndUpdate?url=${encoded_url}" "GET" >/dev/null; then
            bashio::log.info "${app_name} updated successfully"
            return 0
        else
            bashio::log.warning "Failed to update ${app_name}"
            return 1
        fi
    else
        bashio::log.debug "${app_name} is up to date (v${local_version})"
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
