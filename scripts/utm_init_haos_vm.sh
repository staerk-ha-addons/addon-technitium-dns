#!/bin/bash

# ================================
# CONFIGURATION
# ================================
VM_NAME="Home Assistant OS"
ARCH="aarch64"
IMAGE_BASENAME="haos_generic-${ARCH}"
XZ_EXT=".qcow2.xz"
ADDON_DIR="$(PWD)/.."
VM_DIR="${ADDON_DIR}/.vm"
IMAGE_DIR="${VM_DIR}/images"
UTM_VM_DIR="${HOME}/Library/Containers/com.utmapp.UTM/Data/Documents/${VM_NAME}.utm"
QEMU_IMG="/opt/homebrew/bin/qemu-img"

# ================================
# 0. Prepare .vm folder and .gitignore
# ================================
mkdir -p "${VM_DIR}" "${IMAGE_DIR}"
touch "${ADDON_DIR}/.gitignore"
grep -qxF '.vm/' "${ADDON_DIR}/.gitignore" || echo '.vm/' >>"../.gitignore"

# ================================
# 1. Download latest HAOS if needed
# ================================
echo "🔍 Checking for latest Home Assistant OS image..."
RELEASE_DATA=$(curl -s https://api.github.com/repos/home-assistant/operating-system/releases/latest)
DOWNLOAD_URL=$(echo "${RELEASE_DATA}" | jq -r ".assets[] | select(.name | contains (\"${IMAGE_BASENAME}\") and contains(\"${XZ_EXT}\")) | .browser_download_url")

if [[ -z ${DOWNLOAD_URL} ]]; then
	echo "❌ Could not find the latest HAOS image."
	exit 1
fi

XZ_FILE="${IMAGE_DIR}/$(basename "${DOWNLOAD_URL}")"
QCOW_FILE="${XZ_FILE%.xz}"
VM_IMAGE_NAME="$(basename "${QCOW_FILE}")"

if [[ ! -f ${QCOW_FILE} ]]; then
	echo "🌐 Downloading Home Assistant OS..."
	curl -L -o "${XZ_FILE}" "${DOWNLOAD_URL}"
	echo "📦 Decompressing..."
	xz -d "${XZ_FILE}"
fi

# ================================
# 2. Create VM with AppleScript
# ================================
echo "🚀 Creating VM in UTM..."
VM_ID=$(
	osascript <<EOF
tell application "UTM"
	set vmName to "${VM_NAME}"
	set vmArchitecture to "${ARCH}"
	set vmMemoryMB to 4096
	set qcow2 to POSIX file "${QCOW_FILE}" as alias
	set share to POSIX file "${ADDON_DIR}" as alias
	set vmqcow2 to "${UTM_VM_DIR}/Data/${VM_IMAGE_NAME}"
	set extraDiskSizeGB to 64
	set guestMountPoint to "/addons/local"
	log "🔍 Starting UTM VM setup..."
	log "🔍 Checking for existing VM named " & vmName
	try
		set existingVM to virtual machine named vmName
		log "⚠️ VM '" & vmName & "' exists. Deleting it..."
		stop existingVM by kill
		delay 1
		delete existingVM
		delay 1
		log "✅ VM deleted."
	on error
		log "✅ No existing VM found with this name."
	end try
	log "📦 QCOW2 image set to: " & qcow2
	log "📂 Shared folder path: " & share
	log "⚙️ Creating new VM named '" & vmName & "'..."
	set vm to make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:vmArchitecture, memory:vmMemoryMB, hypervisor:true, uefi:true, directory share mode:VirtFS, drives:{{removable:false, source:qcow2}}, network interfaces:{{mode:bridged}}}}
	log "✅ VM created."
	log "🔧 Updating VM registry with shared folder..."
	update registry vm with {{share}}
	log "✅ Registry updated."
    log "⏳ Waiting for " & quoted form of vmqcow2
	tell current application
		repeat
			try
				do shell script "test -f " & quoted form of vmqcow2
				exit repeat
			on error
				log "⏳ Waiting for disk file to appear..."
				delay 1
			end try
		end repeat
	end tell
	delay 3
	log "📏 Resizing QCOW2 disk to " & extraDiskSizeGB & " GB..."
	try
		do shell script "${QEMU_IMG} resize " & quoted form of (POSIX path of vmqcow2) & " +" & extraDiskSizeGB & "G"
		log "✅ Disk resized to " & extraDiskSizeGB & " GB."
	on error errMsg
		log "❌ Failed to resize disk: " & errMsg
	end try
	delay 1
	log "🚀 Starting VM..."
	start vm
	log "⏳ Waiting for VM to boot..."
	repeat
		if status of vm is started then
			log "✅ VM is started."
			exit repeat
		end if
	end repeat
	log "⏳ Waiting for guest agent to be ready..."
	set startTime to current date
	set timeoutSeconds to 300 -- 5 minute timeout
	repeat
		try
			-- Improved guest command execution with proper result handling
			set testProcess to execute of vm at "true" with output
			set testResult to get result testProcess
			
			if exited of testResult is true and exit code of testResult is 0 then
				log "✅ Guest agent is ready!"
				exit repeat
			else
				error "Guest command execution failed"
			end if
		on error errMsg number errNum
			set elapsedSeconds to ((current date) - startTime) / 60
			if elapsedSeconds > timeoutSeconds then
				log "⚠️ Timeout waiting for guest agent to become ready after " & elapsedSeconds & " seconds"
				error "Guest agent timeout"
			end if
			log "⌛ Guest agent not ready yet... Retrying in 3s"
			delay 3
		end try
	end repeat
    delay 3
	log "🌐 VM ip: " & (get item 1 of (query ip of vm))
	log "🪪 VM id: " & (id of vm)
	log "🏁 VM setup complete."
	return the id of vm
end tell
EOF
)
echo "🆔 VM ID is: ${VM_ID}"
echo "${VM_ID}" >"${VM_DIR}/.last_vm_id"

# ================================
# 5. Apply xattrs for root mapping
# ================================
echo "🔐 Applying xattrs to ${ADDON_DIR}"
xattr -r -d user.virtfs.uid "${ADDON_DIR}" 2>/dev/null
xattr -r -d user.virtfs.gid "${ADDON_DIR}" 2>/dev/null

find "${ADDON_DIR}" \( -path "${ADDON_DIR}/.git" -o -path "${ADDON_DIR}/.vm" \) -prune -o -exec xattr -w -x user.virtfs.uid 00000000 {} \;
find "${ADDON_DIR}" \( -path "${ADDON_DIR}/.git" -o -path "${ADDON_DIR}/.vm" \) -prune -o -exec xattr -w -x user.virtfs.gid 00000000 {} \;

echo "✅ VM ready to use."

# ================================
# TO DO - not automated yet
# ================================
# Not automated yet, as Home Assistant OS is mounted read-only, so we need to do this manually.
# - Login to homeassistant.local
# - Install Advanced SSH & Web Terminal add-on
#   - Configure with root access
# - SSH into homeassistant.local
# - Mount /addons/local
#   `mount -t 9p -o trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto share /addons/local`
# - Update /etc/fstab
#   `share /addons/local 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto`
# - Restart systemd
#   `systemctl daemon-reload`
#   `restart network-fs.target`

# ================================
# Solutions ideas
# ================================
# - Update qcow2 image before starting the VM
# - Use serial port to tty into Guest VM with root user (no password) and:
#   # NOTE: Can't get AppleScript to add the serial port to the VM, so we need to do this manually. Or it might be done as a update to the VM?
#   - use HA CLI to install the Advanced SSH & Web Terminal add-on
#   - SSH into add-on from host and:
#     - mount /addons/local
#     - update /etc/fstab
#     - restart systemd
# - Look into using pkl? + UTM Server
#   - https://github.com/tikoci/mikropkl/tree/main

# ================================
# Furure improvements
# ================================
# - Use HA CLI to install our add-on
# - Hook it up with Visual Studio Code tasks

# ================================
# Documentation
# ================================
# https://docs.getutm.app/scripting/reference/
# https://docs.getutm.app/guest-support/linux/#virtfs
