#!/bin/sh
set -e

# ── Запуск S-UI в фоне ──────────────────────────────────────────────────────
/app/entrypoint.sh &
S_UI_PID=$!

# ── Ожидание готовности S-UI на порту 2095 (таймаут 90 сек) ─────────────────
echo "[entrypoint] Waiting for S-UI on :2095 (max 90s)..."
TIMEOUT=90
ELAPSED=0

until curl -sf http://localhost:2095/ > /dev/null 2>&1; do
    # Если процесс S-UI упал — выходим сразу
    if ! kill -0 "$S_UI_PID" 2>/dev/null; then
        echo "[entrypoint] ERROR: S-UI process (PID $S_UI_PID) died unexpectedly."
        exit 1
    fi
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "[entrypoint] ERROR: S-UI did not respond within ${TIMEOUT}s. Aborting."
        kill "$S_UI_PID" 2>/dev/null || true
        exit 1
    fi
    ELAPSED=$((ELAPSED + 2))
    sleep 2
done

echo "[entrypoint] S-UI is ready (${ELAPSED}s). Starting nginx..."

# ── При завершении nginx убиваем S-UI ────────────────────────────────────────
cleanup() {
    echo "[entrypoint] Shutting down S-UI (PID $S_UI_PID)..."
    kill "$S_UI_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Запускаем nginx на переднем плане ────────────────────────────────────────
exec nginx -g "daemon off;"
