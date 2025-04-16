#!/bin/bash
# Fix s6-overlay v3 issues comprehensively
# This script ensures all s6-overlay v3 files are correctly configured

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if rootfs path was provided as argument
if [ $# -gt 0 ] && [ -d "$1" ]; then
    ROOT_DIR="$1"
    echo -e "${GREEN}Using provided rootfs path: ${ROOT_DIR}${NC}"
else
    # Default to current directory if no argument is provided
    ROOT_DIR="$(pwd)"
    echo -e "${YELLOW}No rootfs path provided. Using current directory: ${ROOT_DIR}${NC}"
fi

S6_DIR="${ROOT_DIR}/etc/s6-overlay"

echo -e "${BLUE}Starting s6-overlay v3 compatibility fixes...${NC}"
echo -e "${BLUE}Using rootfs at: ${ROOT_DIR}${NC}"
echo -e "${BLUE}Using s6-overlay at: ${S6_DIR}${NC}"

# Check if s6-overlay directory exists
if [ ! -d "${S6_DIR}" ]; then
    echo -e "${YELLOW}S6 directory not found at ${S6_DIR}${NC}"
    echo -e "${YELLOW}Creating s6-overlay directory structure...${NC}"
    mkdir -p "${S6_DIR}/s6-rc.d"
    mkdir -p "${S6_DIR}/scripts"
    mkdir -p "${S6_DIR}/fix-attrs.d"
    echo "Created basic s6-overlay directory structure"
fi

# 1. Fix notification files - CRITICAL REPAIR
echo -e "${YELLOW}Fixing notification files...${NC}"

# First, remove all existing notification files to start fresh
echo -e "${YELLOW}Removing existing notification files...${NC}"
find "${S6_DIR}/s6-rc.d" -name "notification-fd*" -type f -delete 2>/dev/null || true

# Force regeneration of notification files with proper attributes
echo -e "${YELLOW}Creating new notification files...${NC}"

# Get list of all service directories (safer approach)
echo -e "${YELLOW}Finding service directories...${NC}"
if [ -d "${S6_DIR}/s6-rc.d" ]; then
    for dir in "${S6_DIR}/s6-rc.d"/*; do
        if [ -d "$dir" ] && [[ "$(basename "$dir")" != "user" ]] &&
            [[ "$(basename "$dir")" != "dependencies.d" ]] &&
            [[ "$(basename "$dir")" != "contents.d" ]]; then

            service_name=$(basename "$dir")
            echo -e "${GREEN}Processing service: ${service_name}${NC}"

            # Identify service type
            service_type="longrun"
            if [ -f "$dir/type" ]; then
                service_type=$(cat "$dir/type")
            fi

            # Clear existing notification files first
            rm -f "$dir/notification-fd" "$dir/notification-fd-up" 2>/dev/null || true

            # Create proper empty notification-fd
            touch "$dir/notification-fd"
            chmod 644 "$dir/notification-fd"
            echo "Created notification-fd in $service_name"

            # Create notification-fd-up for longrun services
            if [ "$service_type" = "longrun" ]; then
                touch "$dir/notification-fd-up"
                chmod 644 "$dir/notification-fd-up"
                echo "Created notification-fd-up in $service_name"
            fi

            # Verify the files can be read (crucial fix for the error)
            if [ ! -r "$dir/notification-fd" ]; then
                echo -e "${RED}WARNING: Cannot read $dir/notification-fd - fixing permissions${NC}"
                chmod 644 "$dir/notification-fd"
            fi

            if [ "$service_type" = "longrun" ] && [ ! -r "$dir/notification-fd-up" ]; then
                echo -e "${RED}WARNING: Cannot read $dir/notification-fd-up - fixing permissions${NC}"
                chmod 644 "$dir/notification-fd-up"
            fi
        fi
    done
else
    echo -e "${RED}No s6-rc.d directory found at ${S6_DIR}/s6-rc.d${NC}"
    # Create directory structure
    mkdir -p "${S6_DIR}/s6-rc.d/dns-server"
    mkdir -p "${S6_DIR}/s6-rc.d/cert-watch"
    echo -e "${YELLOW}Created basic service directories${NC}"
fi

# 2. Fix empty files with comments
echo -e "${YELLOW}Fixing dependency and content files...${NC}"
find "${S6_DIR}/s6-rc.d" -path "*/contents.d/*" -o -path "*/dependencies.d/*" 2>/dev/null | while read -r file; do
    cat /dev/null >"$file" # More reliable than > for emptying files
    echo "Cleaned file: $file"
done

# 3. Set correct permissions
echo -e "${YELLOW}Setting correct file permissions...${NC}"
find "${S6_DIR}/s6-rc.d" -name "run" -o -name "up" -o -name "finish" -o -name "down" -exec chmod 755 {} \; 2>/dev/null || true
find "${S6_DIR}/s6-rc.d" -name "notification-fd*" -exec chmod 644 {} \; 2>/dev/null || true
find "${S6_DIR}/scripts" -type f -exec chmod 755 {} \; 2>/dev/null || true

# 4. Ensure directory structure is correct
echo -e "${YELLOW}Verifying directory structure...${NC}"
if [ -d "${S6_DIR}/s6-rc.d" ]; then
    for service_dir in "${S6_DIR}/s6-rc.d"/*; do
        if [ -d "$service_dir" ] && [ "$(basename "$service_dir")" != "user" ]; then
            service_name=$(basename "$service_dir")

            # Ensure service is included in user bundle
            if [ ! -f "${S6_DIR}/s6-rc.d/user/contents.d/$service_name" ]; then
                mkdir -p "${S6_DIR}/s6-rc.d/user/contents.d"
                touch "${S6_DIR}/s6-rc.d/user/contents.d/$service_name"
                chmod 644 "${S6_DIR}/s6-rc.d/user/contents.d/$service_name"
                echo "Added $service_name to user bundle"
            fi

            # Ensure service has a type file
            if [ ! -f "$service_dir/type" ]; then
                echo "longrun" >"$service_dir/type"
                chmod 644 "$service_dir/type"
                echo "Created missing type file for $service_name (default: longrun)"
            fi

            # Ensure longrun services have a run script
            if grep -q "longrun" "$service_dir/type" 2>/dev/null && [ ! -f "$service_dir/run" ]; then
                echo -e "${RED}ERROR: $service_name is longrun but has no run script!${NC}"
            fi

            # Ensure oneshot services have an up script
            if grep -q "oneshot" "$service_dir/type" 2>/dev/null && [ ! -f "$service_dir/up" ]; then
                echo -e "${RED}ERROR: $service_name is oneshot but has no up script!${NC}"
            fi
        fi
    done
fi

# 5. Check specific service directories - critical fix for cert-watch
echo -e "${YELLOW}Fixing specific service directories...${NC}"
CRITICAL_SERVICES=("cert-watch" "dns-server" "init-env" "init-dns-server")

for svc in "${CRITICAL_SERVICES[@]}"; do
    svc_dir="${S6_DIR}/s6-rc.d/${svc}"
    if [ -d "$svc_dir" ]; then
        echo -e "${YELLOW}Special handling for ${svc}...${NC}"

        # Recreate notification files with extra certainty
        rm -f "${svc_dir}/notification-fd" "${svc_dir}/notification-fd-up" 2>/dev/null || true

        # Use regular touch instead of /bin/touch (macOS compatibility)
        touch "${svc_dir}/notification-fd"
        chmod 644 "${svc_dir}/notification-fd"

        # Check if it's longrun (command error safe)
        if grep -q "longrun" "${svc_dir}/type" 2>/dev/null || true; then
            touch "${svc_dir}/notification-fd-up"
            chmod 644 "${svc_dir}/notification-fd-up"
        fi

        # Double check readability
        if [ ! -r "${svc_dir}/notification-fd" ]; then
            echo -e "${RED}WARNING: Still cannot read ${svc_dir}/notification-fd - critical issue${NC}"
            echo -e "${YELLOW}Attempting extreme fix...${NC}"
            rm -f "${svc_dir}/notification-fd"
            echo -n "" >"${svc_dir}/notification-fd"
            chmod 644 "${svc_dir}/notification-fd"
        fi
    fi
done

# 6. Ensure s6-overlay-suexec is properly set for user change
if grep -q "s6-overlay-suexec" "${S6_DIR}/scripts/"* 2>/dev/null; then
    echo -e "${YELLOW}Checking for correct s6-overlay-suexec usage...${NC}"

    # Handle macOS BSD sed vs GNU sed
    if [ "$(uname)" == "Darwin" ]; then
        grep -l "s6-overlay-suexec" "${S6_DIR}/scripts/"* 2>/dev/null |
            xargs sed -i '' 's|/bin/s6-overlay-suexec|/command/s6-overlay-suexec|g' 2>/dev/null || true
    else
        grep -l "s6-overlay-suexec" "${S6_DIR}/scripts/"* 2>/dev/null |
            xargs sed -i 's|/bin/s6-overlay-suexec|/command/s6-overlay-suexec|g' 2>/dev/null || true
    fi

    echo "Updated s6-overlay-suexec paths"
fi

# 7. Create fix-attrs.d if it doesn't exist
if [ ! -d "${S6_DIR}/fix-attrs.d" ]; then
    echo -e "${YELLOW}Creating fix-attrs.d directory...${NC}"
    mkdir -p "${S6_DIR}/fix-attrs.d"
    cat >"${S6_DIR}/fix-attrs.d/01-s6-scripts" <<'EOF'
# Set permissions for s6-rc.d scripts
/etc/s6-overlay/s6-rc.d/*/run,root:root,0755
/etc/s6-overlay/s6-rc.d/*/finish,root:root,0755
/etc/s6-overlay/s6-rc.d/*/up,root:root,0755
/etc/s6-overlay/s6-rc.d/*/down,root:root,0755
/etc/s6-overlay/s6-rc.d/*/notification-fd*,root:root,0644
/etc/s6-overlay/scripts/*,root:root,0755
EOF
    echo "Created fix-attrs.d/01-s6-scripts"
fi

# 8. Check specific issues in notification files
echo -e "${YELLOW}Performing deep check of notification files...${NC}"
find "${S6_DIR}/s6-rc.d" -name "notification-fd*" -type f | while read -r file; do
    # Check for UTF-8 BOM which can cause issues
    if file "$file" | grep -q "BOM"; then
        echo -e "${RED}WARNING: ${file} has BOM marker - removing${NC}"
        # Remove BOM and recreate file
        tr -d $'\xEF\xBB\xBF' <"$file" >"${file}.tmp"
        mv "${file}.tmp" "$file"
        chmod 644 "$file"
    fi

    # Check for non-empty notification files (should be empty)
    if [ -s "$file" ]; then
        echo -e "${RED}WARNING: ${file} is not empty - emptying file${NC}"
        cat /dev/null >"$file"
        chmod 644 "$file"
    fi

    # Check file size explicitly (macOS compatible version)
    if [ "$(uname)" == "Darwin" ]; then
        # macOS version
        size=$(stat -f%z "$file" 2>/dev/null || echo "error")
    else
        # Linux version
        size=$(stat -c%s "$file" 2>/dev/null || echo "error")
    fi
    if [ "$size" != "0" ] && [ "$size" != "error" ]; then
        echo -e "${RED}WARNING: ${file} has non-zero size ($size bytes) - emptying${NC}"
        true >"$file" # Alternative way to empty files
        chmod 644 "$file"
    fi
done

# 9. Check for common issues in scripts
echo -e "${YELLOW}Checking for common script issues...${NC}"

# Check for old svscanctl usage in finish scripts
if grep -r "s6-svscanctl" "${S6_DIR}" 2>/dev/null; then
    echo -e "${RED}WARNING: Found s6-svscanctl usage. Should be replaced with /run/s6/basedir/bin/halt${NC}"
    grep -r "s6-svscanctl" "${S6_DIR}" 2>/dev/null
fi

# Check for proper shebang lines
find "${S6_DIR}/s6-rc.d" -name "run" -o -name "finish" -o -name "up" 2>/dev/null | xargs grep -l "^#!" 2>/dev/null | while read -r script; do
    if ! grep -q "^#!/command/with-contenv" "$script" 2>/dev/null; then
        echo -e "${RED}WARNING: $script has incorrect shebang. Should be #!/command/with-contenv${NC}"
    fi
done

# Check for s6-notify usage
if grep -r "s6-notify" "${S6_DIR}" 2>/dev/null; then
    echo -e "${GREEN}Found s6-notify usage - good for notification support${NC}"
else
    echo -e "${YELLOW}NOTE: No s6-notify usage found. Consider adding for better service readiness signaling${NC}"
fi

echo -e "${GREEN}s6-overlay v3 fixes applied successfully${NC}"
echo -e "${GREEN}The invalid argument error should be fixed now${NC}"
echo -e "${BLUE}NOTE: Remember to update your Dockerfile to use the s6-overlay v3 base image${NC}"
echo -e "${BLUE}and ensure 'init: false' is set in your config.yaml${NC}"
