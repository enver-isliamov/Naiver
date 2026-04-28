#!/bin/bash
set -euo pipefail

# ── Проверка root ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт должен запускаться от root (sudo bash setup_docker.sh)"
    exit 1
fi

# ── Проверка занятости портов ─────────────────────────────────────────────────
for PORT in 80 443 2095 2096; do
    if ss -tlnp | grep -q ":${PORT} "; then
        echo "Ошибка: порт ${PORT} уже занят. Освободите его перед запуском."
        ss -tlnp | grep ":${PORT} "
        exit 1
    fi
done

echo ">>> Порты 80, 443, 2095, 2096 свободны."

# ── 1. Включение BBR на хосте ─────────────────────────────────────────────────
echo ">>> Включение BBR..."
grep -qxF "net.core.default_qdisc=fq" /etc/sysctl.conf \
    || echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
grep -qxF "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf \
    || echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
[[ "$CURRENT_CC" == "bbr" ]] && echo ">>> BBR активен." \
    || echo "Предупреждение: BBR не применился (${CURRENT_CC}). Требуется KVM."

# ── 2. Установка Docker ───────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    echo ">>> Docker уже установлен: $(docker --version)"
else
    echo ">>> Установка Docker..."
    curl -fsSL https://get.docker.com | sh
    # Проверяем что Docker установился
    if ! command -v docker &>/dev/null; then
        echo "Ошибка: Docker не установился. Проверьте интернет-соединение."
        exit 1
    fi
    echo ">>> Docker установлен: $(docker --version)"
fi

# ── 3. Создание папок для данных ──────────────────────────────────────────────
echo ">>> Создание папок данных..."
mkdir -p /root/s-ui/db /root/s-ui/cert

# ── 4. Остановка старого контейнера (если был) ────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -q "^s-ui$"; then
    echo ">>> Найден существующий контейнер s-ui. Останавливаем и удаляем..."
    docker stop s-ui && docker rm s-ui
fi

# ── 5. Запуск контейнера S-UI ─────────────────────────────────────────────────
echo ">>> Запуск контейнера S-UI..."
docker run -itd \
    -p 2095:2095 \
    -p 2096:2096 \
    -p 443:443 \
    -p 80:80 \
    -v /root/s-ui/db/:/app/db/ \
    -v /root/s-ui/cert/:/root/cert/ \
    --name s-ui \
    --restart=unless-stopped \
    alireza7/s-ui:latest

# ── 6. Проверка запуска ───────────────────────────────────────────────────────
echo ">>> Ожидание старта контейнера (15 сек)..."
sleep 15

if docker ps --format '{{.Names}}' | grep -q "^s-ui$"; then
    IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    echo ""
    echo "========================================================"
    echo "  S-UI в Docker запущен!"
    echo "  Адрес панели:  http://${IP}:2095/app/"
    echo "  Логин / пароль: admin / admin"
    echo "  ВАЖНО: Немедленно смените пароль в настройках!"
    echo "  Данные хранятся в /root/s-ui/"
    echo "========================================================"
else
    echo "Ошибка: контейнер не запустился. Логи:"
    docker logs s-ui 2>/dev/null || true
    exit 1
fi
