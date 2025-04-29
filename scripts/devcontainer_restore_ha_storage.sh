#!/bin/bash
set -e

if [[ ! -d "${WORKSPACE_DIRECTORY}/.devcontainer/.storage-backup/" ]]; then
	echo "Directory ${WORKSPACE_DIRECTORY}/.devcontainer/.storage-backup/ does not exist. Skipping .storage restore..."
else
	if [[ "$(docker container inspect -f '{{.State.Status}}' hassio_supervisor 2>/dev/null || true)" != "running" ]]; then
		echo "You need to start the Home Assistant Supervisor before running this script."
		exit 1
	fi

	# Wait until the homeassistant container is running
	while [[ -z "$(docker ps --filter name=homeassistant --format '{{.ID}}' || true)" ]]; do
		echo "Home Assistant container not running yet. Waiting... this might take a while. Please be patient."
		sleep 3
	done

	HA_CONTAINER=$(docker ps --filter name=homeassistant --format '{{.ID}}')
	echo "Home Assistant container is running with ID ${HA_CONTAINER}"

	echo "Copying .storage files..."
	docker cp "${WORKSPACE_DIRECTORY}/.devcontainer/.storage-backup/." "${HA_CONTAINER}":/config/.storage/

	echo "Restarting Home Assistant container..."
	docker restart "${HA_CONTAINER}"
fi
echo "Seeding complete. You can now start Home Assistant normally."
