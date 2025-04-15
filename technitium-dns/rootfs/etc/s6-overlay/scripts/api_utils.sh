#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# API utilities for Technitium DNS Server
# ==============================================================================

# -----------------------------------------------------------------------------
# Debugging and Logging
# -----------------------------------------------------------------------------

LOG_LEVEL=$(bashio::config 'log_level' 'info')
bashio::log.level "$LOG_LEVEL"

# -----------------------------------------------------------------------------
# Constants and Configuration
# -----------------------------------------------------------------------------
TOKEN=""
PASSWORD='admin'
API_SERVER="http://localhost:5380"
readonly TOKEN_NAME="ha-addon-token"
readonly TOKEN_FILE="/config/.$TOKEN_NAME.enc"
readonly LOCK_FILE="/tmp/.api_token.lock"

# Set logging level
#bashio::log.level "debug"

# -----------------------------------------------------------------------------
# Input Validation Functions
# -----------------------------------------------------------------------------
validate_response() {
    local response=$1
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        bashio::log.debug "Invalid JSON response"
        return 1
    fi
    return 0
}

check_required_params() {
    local endpoint=$1
    local method=$2
    [[ -z "$endpoint" ]] && {
        bashio::log.debug "Missing endpoint"
        return 1
    }
    [[ ! "$method" =~ ^(GET|POST)$ ]] && {
        bashio::log.debug "Invalid method: $method"
        return 1
    }
    return 0
}

# -----------------------------------------------------------------------------
# Security Functions
# -----------------------------------------------------------------------------
encrypt_token() {
    local token=$1
    echo "$token" | openssl enc -aes-256-cbc -pbkdf2 -a -salt -pass pass:"$TOKEN_NAME" 2>/dev/null
}

decrypt_token() {
    local encrypted=$1
    echo "$encrypted" | openssl enc -aes-256-cbc -pbkdf2 -a -d -salt -pass pass:"$TOKEN_NAME" 2>/dev/null
}

redact_url() {
    local url=$1
    # Use parameter expansion instead of sed
    local redacted=${url//token=[^&]*\(&\|$\)/token=REDACTED\1}
    echo "$redacted"
}

# -----------------------------------------------------------------------------
# File Lock Management
# -----------------------------------------------------------------------------
acquire_lock() {
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    bashio::log.debug "Could not acquire lock after $max_attempts attempts"
    return 1
}

release_lock() {
    if ! rm -rf "$LOCK_FILE"; then
        bashio::log.debug "Failed to release lock"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Token Management
# -----------------------------------------------------------------------------
save_token() {
    local token=$1
    if acquire_lock; then
        encrypt_token "$token" >"$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        release_lock
        bashio::log.debug "Saved encrypted API token"
        return 0
    fi
    return 1
}

load_saved_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        return 1
    fi

    if ! acquire_lock; then
        return 1
    fi

    local encrypted_token
    local saved_token
    encrypted_token=$(cat "$TOKEN_FILE")
    saved_token=$(decrypt_token "$encrypted_token")
    release_lock

    if [ -z "$saved_token" ]; then
        bashio::log.debug "Failed to decrypt token"
        return 1
    fi

    # Verify token is valid by making a test API call
    if ! response=$(make_direct_call "settings/get?token=$saved_token") ||
        [[ "$response" == *"\"status\":\"Error\""* ]]; then
        return 1
    fi

    if acquire_lock; then
        TOKEN="$saved_token"
        release_lock
        bashio::log.debug "Loaded and verified saved API token"
        return 0
    fi

    if acquire_lock; then
        rm -f "$TOKEN_FILE"
        release_lock
    fi
    bashio::log.debug "Saved token is invalid, will create new one"
    return 1
}

check_token_validity() {
    if [ -n "$TOKEN" ]; then
        response=$(make_direct_call "settings/get?token=$TOKEN")
        if [[ "$response" == *"\"status\":\"Error\""* ]]; then
            return 1
        fi
    fi
    return 0
}

# shellcheck disable=SC2120
get_auth_token() {
    local username=${1:-"admin"}
    local password=${2:-"$PASSWORD"}

    # Try to load existing token first
    if load_saved_token; then
        return 0
    fi

    bashio::log.debug "Creating new API token..."

    # Create permanent token
    if response=$(make_direct_call "user/createToken?user=$username&pass=$password&tokenName=$TOKEN_NAME"); then
        token=$(echo "$response" | jq -r '.token // empty')
        if [ -n "$token" ]; then
            save_token "$token"
            TOKEN="$token"
            return 0
        fi
    fi

    # Fallback to standard login if token creation fails
    bashio::log.debug "API token creation failed, falling back to standard login..."
    if response=$(make_direct_call "user/login?user=$username&pass=$password&includeInfo=true"); then
        token=$(echo "$response" | jq -r '.token // empty')
        if [ -n "$token" ]; then
            bashio::log.debug "Authentication successful using standard login"
            TOKEN="$token"
            return 0
        fi
    fi

    bashio::log.debug "Authentication failed"
    return 1
}

# -----------------------------------------------------------------------------
# API Communication
# -----------------------------------------------------------------------------
make_direct_call() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-""}

    # Validate input parameters
    if ! check_required_params "$endpoint" "$method"; then
        return 1
    fi

    local url="$API_SERVER/api/$endpoint"
    local safe_url
    safe_url=$(redact_url "$url")

    local curl_cmd="curl -s --connect-timeout 10"

    if [ "$method" = "POST" ]; then
        curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json' -d '$data'"
        bashio::log.trace "Making Direct POST call to: $safe_url"
        bashio::log.trace "POST data: $data"
    else
        bashio::log.trace "Making Direct GET call to: $safe_url"
    fi

    # Make the API call and capture response
    response=$(eval "$curl_cmd '$url'")
    local status=$?

    # Validate JSON response if successful
    if [ $status -eq 0 ] && [ -n "$response" ]; then
        if ! validate_response "$response"; then
            bashio::log.debug "Invalid response from API"
            return 1
        fi
    fi

    # Log the response
    if [ $status -eq 0 ]; then
        if [[ "$response" == *"\"status\":\"Error\""* ]]; then
            error_msg=$(echo "$response" | sed -n 's/.*"errorMessage":"\([^"]*\)".*/\1/p')
            bashio::log.debug "Direct API call failed with error: $error_msg"
        else
            bashio::log.trace "Direct API call successful"
            bashio::log.trace "Response: $response"
        fi
    else
        bashio::log.debug "Direct API call failed with curl exit code: $status"
    fi

    echo "$response"
    return $status
}

make_api_call() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-""}
    local max_attempts=30
    local wait_time=2
    local attempt=1

    # Validate input parameters
    if ! check_required_params "$endpoint" "$method"; then
        return 1
    fi

    bashio::log.debug "=== API Call Start ==="
    bashio::log.trace "Endpoint: $endpoint"
    bashio::log.trace "Method: $method"
    [ -n "$data" ] && bashio::log.trace "Data: $data"

    # Check if we need token and don't have one (except for login and ping)
    if [[ -z "$TOKEN" ]] && [[ "$endpoint" != "ping" ]] && [[ ! "$endpoint" =~ ^user/login ]]; then
        bashio::log.debug "No token available, authenticating..."
        if ! get_auth_token; then
            return 1
        fi
    fi

    while [ $attempt -le $max_attempts ]; do
        # Construct endpoint with token if needed
        local api_endpoint="$endpoint"
        if [ -n "$TOKEN" ] && [[ "$endpoint" != "user/login"* ]] && [[ "$endpoint" != "ping" ]]; then
            if [[ "$endpoint" == *"?"* ]]; then
                api_endpoint="${endpoint}&token=$TOKEN"
            else
                api_endpoint="${endpoint}?token=$TOKEN"
            fi
            bashio::log.debug "Added token to endpoint"
        fi

        local safe_endpoint
        safe_endpoint=$(redact_url "$api_endpoint")
        bashio::log.debug "Attempt $attempt/$max_attempts"
        bashio::log.debug "Making API $method call to: $safe_endpoint"
        [ -n "$data" ] && bashio::log.debug "Data: $data \n"
        response=$(make_direct_call "$api_endpoint" "$method" "$data")
        local call_status=$?

        if [ $call_status -eq 0 ]; then
            # Validate response before processing
            if ! validate_response "$response"; then
                bashio::log.debug "Invalid response format"
                return 1
            fi

            # Check if response indicates auth failure
            if [[ "$response" == *"\"status\":\"Error\""* ]] && [[ "$response" == *"\"responseText\":\"Access token invalid or expired\""* ]]; then
                bashio::log.debug "Token expired, getting new token..."
                if ! get_auth_token; then
                    return 1
                fi
                continue
            fi

            bashio::log.debug "API call successful"

            # Buffer the response output
            local formatted_response
            if echo "$response" | jq . >/dev/null 2>&1; then
                formatted_response=$(echo "$response" | jq .)
                bashio::log.debug "$formatted_response"
            else
                bashio::log.debug "$response"
            fi

            # Ensure output is flushed before logging end
            sleep 0.1
            bashio::log.debug "=== API Call End ==="
            return 0
        fi

        bashio::log.debug "API call failed (attempt $attempt/$max_attempts), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
    done

    bashio::log.debug "Failed to connect to API after $max_attempts attempts"
    bashio::log.debug "=== API Call End ==="
    return 1
}

# -----------------------------------------------------------------------------
# App Management
# -----------------------------------------------------------------------------
manage_dns_app() {
    local app_name=$1

    # Validate app name
    if [ -z "$app_name" ]; then
        bashio::log.debug "App name is required"
        return 0
    fi

    bashio::log.debug "Managing DNS app: $app_name"

    # Get store app info and validate response
    if ! store_info=$(make_api_call "apps/listStoreApps" "GET") ||
        ! validate_response "$store_info"; then
        bashio::log.debug "Failed to get valid store apps list"
        return 0
    fi

    # Find app in store
    local app_details
    app_details=$(echo "$store_info" | jq -r --arg name "$app_name" '.response.storeApps[] |
        select(.name == $name) | {
            version: .version,
            url: .url,
            name: .name
        }')

    if [ -z "$app_details" ]; then
        bashio::log.debug "App '$app_name' not found in store"
        return 0
    fi

    # Extract version and encoded name and URLs
    local store_version
    local encoded_url
    local encoded_name
    store_version=$(echo "$app_details" | jq -r '.version')
    encoded_url=$(echo "$app_details" | jq -r '.url | @uri')
    encoded_name=$(echo "$app_details" | jq -r '.name | @uri')

    bashio::log.debug "Found $app_name version $store_version in store"

    # Check if app is installed
    if ! local_info=$(make_api_call "apps/list" "GET"); then
        bashio::log.debug "Failed to get local apps list"
        return 0
    fi

    # Check if app is installed and get version
    local local_version
    local_version=$(echo "$local_info" | jq -r --arg name "$app_name" '.response.apps[] |
        select(.name == $name) | .version // empty')

    # Install or update as needed
    if [ -z "$local_version" ]; then
        bashio::log.debug "Installing $app_name v$store_version..."
        if make_api_call "apps/downloadAndInstall?name=$encoded_name&url=$encoded_url" "GET"; then
            bashio::log.debug "$app_name installed successfully"
            return 0
        else
            bashio::log.debug "Failed to install $app_name"
            return 0
        fi
    elif [ "$local_version" != "$store_version" ]; then
        bashio::log.debug "Updating $app_name from v$local_version to v$store_version..."
        if make_api_call "apps/downloadAndUpdate?url=$encoded_url" "GET"; then
            bashio::log.debug "$app_name updated successfully"
            return 0
        else
            bashio::log.debug "Failed to update $app_name"
            return 0
        fi
    else
        bashio::log.debug "$app_name is up to date (v$local_version)"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
    if [ -d "$LOCK_FILE" ]; then
        rm -rf "$LOCK_FILE"
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
