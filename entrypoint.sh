#!/bin/bash
set -e

# Start S-UI in the background using its original entrypoint/command.
# The base image (alireza7/s-ui:latest) runs the panel on port 2095 by default.
/app/s-ui &
S_UI_PID=$!

# Wait until S-UI's web interface is up on port 2095 before opening the bridge.
echo "Waiting for S-UI to start on port 2095..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:2095/app/ > /dev/null 2>&1; then
        echo "S-UI is up."
        break
    fi
    sleep 1
done

# Forward Railway's public port 80 → S-UI web panel on port 2095.
# socat keeps running in the foreground; if it exits the container exits too.
echo "Starting port bridge: 80 -> 2095"
exec socat TCP-LISTEN:80,fork,reuseaddr TCP:127.0.0.1:2095 &

# Keep the container alive by waiting on the S-UI process.
wait $S_UI_PID
