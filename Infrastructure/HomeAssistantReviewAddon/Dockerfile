FROM ghcr.io/home-assistant/home-assistant:stable

COPY rootfs/run-review-home.sh /run-review-home.sh
COPY seed/configuration.yaml /seed/configuration.yaml

RUN chmod 0755 /run-review-home.sh

LABEL io.hass.version="1.0.1" \
      io.hass.type="addon" \
      io.hass.arch="aarch64"

ENTRYPOINT []
CMD ["/run-review-home.sh"]
