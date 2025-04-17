#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# DNS app management functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# App Management
# -----------------------------------------------------------------------------
# Manage DNS apps (install, update) from Technitium DNS store
api_install_app() {
    local app_name="${1}"
    local operation_result

    # Validate app name
    if [[ -z "${app_name}" ]]; then
        bashio::log.warning "api_utils: App name is required"
        return 1
    fi

    bashio::log.info "api_utils: Managing DNS app: ${app_name}"

    # Get store app info and validate response
    local store_info
    store_info=$(api_call "apps/listStoreApps" "GET")
    api_call_status=$?

    if [[ ${api_call_status} -ne 0 ]]; then
        bashio::log.warning "api_utils: Failed to get store apps list"
        return 1
    fi

    # Check if store API returned an error
    local is_error
    is_error=$(jq -e '.status == "error"' <<<"${store_info}" 2>/dev/null || echo "false")

    if [[ "${is_error}" == "true" ]]; then
        local error_message
        error_message=$(jq -r '.errorMessage // "Unknown error"' <<<"${store_info}")
        bashio::log.warning "api_utils: Store API returned error: ${error_message}"
        return 1
    fi

    # Find app in store
    local app_details
    app_details=$(jq -r --arg name "${app_name}" '.response.storeApps[] |
        select(.name == $name) | {
            version: .version,
            url: .url,
            name: .name
        }' <<<"${store_info}")

    if [[ -z "${app_details}" ]]; then
        bashio::log.warning "api_utils: App '${app_name}' not found in store"
        return 1
    fi

    # Extract version and encoded name and URLs
    local store_version
    local encoded_url
    local encoded_name
    store_version=$(jq -r '.version' <<<"${app_details}")
    encoded_url=$(jq -r '.url | @uri' <<<"${app_details}")
    encoded_name=$(jq -r '.name | @uri' <<<"${app_details}")

    bashio::log.info "api_utils: Found ${app_name} version ${store_version} in store"

    # Check if app is installed
    local local_info
    local_info=$(api_call "apps/list" "GET")
    api_call_status=$?

    if [[ ${api_call_status} -ne 0 ]]; then
        bashio::log.warning "api_utils: Failed to get local apps list"
        return 1
    fi

    # Check if app is installed and get version
    local local_version
    local_version=$(jq -r --arg name "${app_name}" '.response.apps[] |
        select(.name == $name) | .version // empty' <<<"${local_info}")

    # Install or update as needed
    if [[ -z "${local_version}" ]]; then
        bashio::log.info "api_utils: Installing ${app_name} v${store_version}..."

        # Fix SC2310/SC2312: Invoke API call separately to avoid masking return values
        operation_result=$(api_call "apps/downloadAndInstall?name=${encoded_name}&url=${encoded_url}" "GET")
        api_call_status=$?

        if [[ ${api_call_status} -eq 0 ]]; then
            # Check operation result separately to avoid masking jq's return value
            local is_ok
            is_ok=$(jq -e '.status == "ok"' <<<"${operation_result}" 2>/dev/null || echo "false")

            if [[ "${is_ok}" == "true" ]]; then
                bashio::log.info "api_utils: ${app_name} installed successfully"
                return 0
            else
                # Extract error message separately to avoid masking jq's return value
                local error_message
                error_message=$(jq -r '.errorMessage // "Unknown error"' <<<"${operation_result}")
                bashio::log.warning "api_utils: Failed to install ${app_name}: ${error_message}"
                return 1
            fi
        else
            bashio::log.warning "api_utils: Failed to install ${app_name}"
            return 1
        fi
    elif [[ $(api_app_version_compare "${store_version}" "${local_version}" || true) -gt 0 ]]; then
        bashio::log.info "api_utils: Updating ${app_name} from v${local_version} to v${store_version}..."

        # Fix SC2310/SC2312: Invoke API call separately to avoid masking return values
        operation_result=$(api_call "apps/downloadAndUpdate?url=${encoded_url}" "GET")
        api_call_status=$?

        if [[ ${api_call_status} -eq 0 ]]; then
            # Check operation result separately to avoid masking jq's return value
            local is_ok
            is_ok=$(jq -e '.status == "ok"' <<<"${operation_result}" 2>/dev/null || echo "false")

            if [[ "${is_ok}" == "true" ]]; then
                bashio::log.info "api_utils: ${app_name} updated successfully"
                return 0
            else
                # Extract error message separately to avoid masking jq's return value
                local error_message
                error_message=$(jq -r '.errorMessage // "Unknown error"' <<<"${operation_result}")
                bashio::log.warning "api_utils: Failed to update ${app_name}: ${error_message}"
                return 1
            fi
        else
            bashio::log.warning "api_utils: Failed to update ${app_name}"
            return 1
        fi
    else
        bashio::log.debug "api_utils: ${app_name} is up to date (v${local_version})"
        return 0
    fi
}
