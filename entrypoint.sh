#!/bin/sh
set -e

# Start S-UI in the background
/app/entrypoint.sh &

# Wait for S-UI to be ready on port 2095
echo "Waiting for S-UI to be ready on port 2095..."
until curl -sf http://localhost:2095/ > /dev/null 2>&1; do
    sleep 2
done
echo "S-UI is ready. Starting nginx..."

# Start nginx in the foreground so the container stays alive
exec nginx -g "daemon off;"
