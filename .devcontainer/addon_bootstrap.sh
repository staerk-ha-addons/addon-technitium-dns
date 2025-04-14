#!/bin/bash
set -e

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.natesales.net/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/natesales.gpg
echo "deb [signed-by=/etc/apt/keyrings/natesales.gpg] https://repo.natesales.net/apt * *" | sudo tee /etc/apt/sources.list.d/natesales.list
sudo apt update
sudo apt install -y q dnsutils net-tools

if [ ! -d "$WORKSPACE_DIRECTORY/.devcontainer/.storage-backup/" ]; then
  echo "Directory $WORKSPACE_DIRECTORY/.devcontainer/.storage-backup/ does not exist. Skipping .storage restore..."
else
  if [ ! "$(docker container inspect -f '{{.State.Status}}' hassio_supervisor 2>/dev/null)" == "running" ]; then
    echo "You need to start the Home Assistant Supervisor before running this script."
  fi

  # Wait until the homeassistant container is running
  while [ -z "$(docker ps --filter name=homeassistant --format '{{.ID}}')" ]; do
    echo "Home Assistant container not running yet. Waiting..."
    sleep 2
  done

  HA_CONTAINER=$(docker ps --filter name=homeassistant --format '{{.ID}}')
  echo "Home Assistant container is running with ID $HA_CONTAINER"

  echo "Copying .storage files..."
  docker cp "$WORKSPACE_DIRECTORY/.devcontainer/.storage-backup/." "$HA_CONTAINER":/config/.storage/

  echo "Restarting Home Assistant container..."
  docker restart "$HA_CONTAINER"
fi
echo "Seeding complete. You can now start Home Assistant normally."
