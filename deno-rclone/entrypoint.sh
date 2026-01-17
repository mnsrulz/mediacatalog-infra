#!/bin/bash

mkdir -p /data           ## for storing the media content
mkdir -p /cache           ## for storing the cache
mkdir -p /rcloneconfig    ## for storing the rclone config

# Start Rclone mount in the background
rclone mount -v --allow-non-empty --allow-other --read-only --vfs-read-chunk-size=4M \
    --vfs-read-chunk-size-limit=16M --vfs-cache-mode=full --buffer-size=256K --no-checksum \
    --cache-dir=/cache --vfs-cache-max-size=1G blobmzodata: /data --config /rcloneconfig/rclone.conf &

# Wait for Rclone to mount
while ! mountpoint -q /data; do
  echo "Waiting for Rclone mount..."
  sleep 1
done

echo "Rclone mount is ready."

deno run --allow-all https://raw.githubusercontent.com/mnsrulz/mztrading-data/refs/heads/main/api/worker.ts