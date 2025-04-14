#!/bin/bash
set -e

if [ "$(docker container inspect -f '{{.State.Status}}' hassio_supervisor 2>/dev/null)" == "running" ]; then
  echo "Starting Home Assistant with supervisor_run..."
  supervisor_run &
  SUPERVISOR_PID=$!
else
  echo "hassio_supervisor is not running, skipping supervisor_run."
  SUPERVISOR_PID=""
fi

echo "Waiting for Home Assistant container to be running..."

# Wait until the homeassistant container is running
while [ -z "$(docker ps --filter name=homeassistant --format {{.ID}})" ]; do
  echo "Home Assistant container not running yet. Waiting..."
  sleep 2
done

HA_CONTAINER=$(docker ps --filter name=homeassistant --format {{.ID}})
echo "Home Assistant container is running with ID $HA_CONTAINER"

echo "Backing up .storage from Home Assistant container..."

# Ensure backup dir exists
mkdir -p $WORKSPACE_DIRECTORY/.devcontainer/.storage-backup

# Copy files from Home Assistant container
docker cp "$HA_CONTAINER":/config/.storage/. $WORKSPACE_DIRECTORY/.devcontainer/.storage-backup/

if [ -n "$SUPERVISOR_PID" ]; then
  echo "Stopping supervisor_run (PID $SUPERVISOR_PID)..."
  kill "$SUPERVISOR_PID" || kill -9 "$SUPERVISOR_PID"
fi

echo "Backup completed. Files saved to /config/.storage-backup/"