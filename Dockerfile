FROM alireza7/s-ui:latest

# Install socat to forward Railway's required port 80 → S-UI's web port 2095
RUN apk add --no-cache socat

# Copy custom entrypoint that starts S-UI then bridges port 80 → 2095
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443 2095 2096

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:80/app/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
