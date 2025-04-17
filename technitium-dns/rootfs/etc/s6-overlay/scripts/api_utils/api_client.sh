#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# API client functions for making API requests
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# API Communication
# -----------------------------------------------------------------------------
# Make a direct API call without authentication
api_direct() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"

    # Validate input parameters
    if ! api_check_required_params "${endpoint}" "${method}"; then
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
    safe_url=$(api_redact_url "${url}")

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
        # Validate separately to handle SC2310/SC2312
        api_validate_response "${response}"
        validation_status=$?

        if [[ ${validation_status} -ne 0 ]]; then
            bashio::log.warning "api_utils: Invalid response from API"
            return 1
        fi
    fi

    echo "${response}"
    return "${status}"
}

# Make an authenticated API call with retry logic
api_call() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"
    local max_attempts=30
    local wait_time=2
    local attempt=1
    local token
    local backoff_factor=1.5

    # Get authentication token
    token=$(api_get_token)
    token_status=$?

    if [[ ${token_status} -ne 0 ]]; then
        bashio::log.error "api_utils: Failed to obtain authentication token"
        return 1
    fi

    # Validate input parameters
    if ! api_check_required_params "${endpoint}" "${method}"; then
        return 1
    fi

    bashio::log.debug "api_utils: === API Call Start ==="
    bashio::log.debug "api_utils: Endpoint: ${endpoint}"
    bashio::log.debug "api_utils: Method: ${method}"

    # Log data if available (for debugging)
    if [[ -n "${data}" ]]; then
        local formatted_data
        formatted_data=$(jq -c . <<<"${data}" 2>/dev/null || echo "${data}")
        bashio::log.debug "api_utils: Data: ${formatted_data}"
    fi

    # Retry loop for API calls with exponential backoff
    while [[ ${attempt} -le ${max_attempts} ]]; do
        bashio::log.debug "api_utils: Attempt ${attempt}/${max_attempts}"

        # Construct endpoint with token
        local api_endpoint="${endpoint}"
        if [[ -n "${token}" ]]; then
            if [[ "${endpoint}" == *"?"* ]]; then
                api_endpoint="${endpoint}&token=${token}"
            else
                api_endpoint="${endpoint}?token=${token}"
            fi
        fi

        # Make the API call - avoiding SC2312
        local response
        response=$(api_direct "${api_endpoint}" "${method}" "${data}")
        local call_status=$?

        if [[ ${call_status} -ne 0 ]]; then
            # Calculate next wait time with exponential backoff
            wait_time=$(awk "BEGIN {print int(${wait_time} * ${backoff_factor})}")

            # Cap wait time at 30 seconds
            [[ ${wait_time} -gt 30 ]] && wait_time=30

            bashio::log.debug "api_utils: API call failed (attempt ${attempt}/${max_attempts}), retrying in ${wait_time}s..."
            sleep "${wait_time}"
            attempt=$((attempt + 1))
            continue
        fi

        # Validate response - avoiding SC2310
        api_validate_response "${response}"
        validation_status=$?

        if [[ ${validation_status} -ne 0 ]]; then
            bashio::log.warning "api_utils: Invalid response format"
            return 1
        fi

        # Check for authentication errors in response - avoiding SC2310
        local has_auth_error
        has_auth_error=$(jq -e '.status == "error" and .errorMessage | test("(?i)auth|token|login|credential")' <<<"${response}" 2>/dev/null || echo "false")

        if [[ "${has_auth_error}" == "true" ]]; then
            bashio::log.warning "api_utils: Authentication error detected, refreshing token..."

            # Remove old token file to force recreation
            if api_acquire_lock; then
                rm -f "${ADDON_TOKEN_FILE}"
                api_release_lock
            fi

            # Get new token - avoiding SC2312
            token=$(api_get_token)
            token_status=$?

            if [[ ${token_status} -ne 0 ]]; then
                bashio::log.error "api_utils: Failed to refresh authentication token"
                return 1
            fi

            # Try again with new token
            wait_time=2
            attempt=$((attempt + 1))
            continue
        fi

        # Format and log response
        bashio::log.debug "api_utils: API call successful"

        # Check JSON formatting - avoiding SC2310
        local is_json
        jq -e . <<<"${response}" >/dev/null 2>&1
        is_json=$?

        if [[ ${is_json} -eq 0 ]]; then
            local formatted_response
            formatted_response=$(jq -c . <<<"${response}")
            bashio::log.trace "api_utils: ${formatted_response}"
        else
            bashio::log.trace "api_utils: ${response}"
        fi

        # Ensure logging output is complete before returning
        bashio::log.debug "api_utils: === API Call End ==="
        echo "${response}"
        return 0
    done

    bashio::log.error "api_utils: Failed to connect to API after ${max_attempts} attempts"
    bashio::log.debug "api_utils: === API Call End ==="
    return 1
}
