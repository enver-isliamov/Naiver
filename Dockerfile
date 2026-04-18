FROM alireza7/s-ui:latest

EXPOSE 80 443 2095 2096

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:2095/app/ || exit 1
