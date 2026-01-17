FROM rclone/rclone:v1.72-stable AS rclone

FROM denoland/deno:2.6.0

COPY --from=rclone /usr/local/bin/rclone /usr/bin/rclone

# GOT this from rclone dockerfile
RUN echo "**** Install Dependencies ****" && \
    apt update && \
    apt install -y \
        ca-certificates \
        fuse3 \
        tzdata && \
    echo "Enable user_allow_other in fuse" && \
    echo "user_allow_other" >> /etc/fuse.conf

# Likely not needed as rclone copies permissions over
# RUN addgroup -g 1009 rclone && adduser -u 1009 -Ds /bin/sh -G rclone rclone

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]