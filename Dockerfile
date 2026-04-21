FROM alireza7/s-ui:latest

# Tell S-UI to listen directly on port 80 — no socat bridge needed
ENV PORT=80

EXPOSE 80 443 2096

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:80/app/ || exit 1
