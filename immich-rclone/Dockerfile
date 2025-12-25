FROM rclone/rclone:v1.72-stable AS rclone

FROM ghcr.io/immich-app/immich-server:v2.3.1 

COPY --from=rclone /usr/local/bin/rclone /usr/bin/rclone

