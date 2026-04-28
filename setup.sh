#!/bin/bash
set -euo pipefail

# ── Проверка root ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: скрипт должен запускаться от root (sudo bash setup.sh)"
    exit 1
fi

# ── Проверка занятости портов 80 и 443 ───────────────────────────────────────
for PORT in 80 443; do
    if ss -tlnp | grep -q ":${PORT} "; then
        echo "Ошибка: порт ${PORT} уже занят. Освободите его перед установкой."
        ss -tlnp | grep ":${PORT} "
        exit 1
    fi
done

echo ">>> Порты 80 и 443 свободны. Продолжаем установку..."

# ── 1. Обновление системы ─────────────────────────────────────────────────────
echo ">>> Обновление системы..."
apt update && apt upgrade -y
apt install -y curl wget sudo

# ── 2. Включение BBR ──────────────────────────────────────────────────────────
echo ">>> Включение BBR..."
# Добавляем только если строки ещё не существуют
grep -qxF "net.core.default_qdisc=fq" /etc/sysctl.conf \
    || echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
grep -qxF "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf \
    || echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

sysctl -p

# Проверяем, что BBR реально активен
CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$CURRENT_CC" == "bbr" ]]; then
    echo ">>> BBR активен."
else
    echo "Предупреждение: BBR не применился (${CURRENT_CC}). Требуется KVM-виртуализация."
fi

# ── 3. Установка панели S-UI ──────────────────────────────────────────────────
echo ">>> Установка S-UI..."
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)

# ── 4. Итоговая информация ────────────────────────────────────────────────────
IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
echo ""
echo "========================================================"
echo "  Установка завершена!"
echo "  Адрес панели:  http://${IP}:2095/app/"
echo "  Логин / пароль: admin / admin"
echo "  ВАЖНО: Немедленно смените пароль в настройках!"
echo "========================================================"
