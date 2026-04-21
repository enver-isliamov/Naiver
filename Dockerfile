FROM alireza7/s-ui:latest

# Install nginx to reverse proxy port 80 → 2095 (S-UI's hardcoded port)
RUN apk add --no-cache nginx

# Copy nginx reverse proxy config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy and set up custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443 2096

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:80/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
