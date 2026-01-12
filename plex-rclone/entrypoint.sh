#!/bin/bash

mkdir -p /media

# Start Rclone mount in the background
rclone mount -v --allow-non-empty --allow-other --read-only --vfs-read-chunk-size=1M \
    --vfs-read-chunk-size-limit=8M --dir-cache-time=5s media: /media --config /config/rclone/rclone.conf &

# Wait for Rclone to mount
while ! mountpoint -q /media; do
  echo "Waiting for Rclone mount..."
  sleep 1
done

echo "Rclone mount is ready."

# Start Plex
exec /init