FROM alireza7/s-ui:latest

# curl нужен для healthcheck и ожидания в entrypoint
# nginx — reverse proxy port 80 → 2095 (S-UI hardcoded port)
RUN apk add --no-cache nginx curl

# Copy nginx reverse proxy config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy and set up custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 80   — UI панели (через nginx → 2095)
# 443  — NaiveProxy / sing-box (напрямую)
# 2096 — Дополнительный протокол sing-box (напрямую)
EXPOSE 80 443 2096

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:80/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
