#!/bin/bash
# =============================================================================
#  Установщик NaiveProxy + S-UI с доступом через порт 80 (работает из коробки)
#  Репозиторий: github.com/enver-isliamov/Naiver
#  Запуск: curl -sL https://raw.githubusercontent.com/enver-isliamov/Naiver/main/setup.sh | bash
# =============================================================================
set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; exit 1; }
step() { echo -e "\n${BOLD}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Проверка root
step "Шаг 0/6: Проверка прав доступа"
if [[ $EUID -ne 0 ]]; then
    fail "Скрипт нужно запускать от root.\nПопробуйте: sudo bash setup.sh"
fi
ok "Запущен от root"

# Проверка портов
info "Проверяю, не заняты ли порты 80 и 443..."
for PORT in 80 443; do
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
        fail "Порт ${PORT} уже занят другой программой.\nОстановите её и запустите скрипт снова.\nЧтобы узнать что занимает порт: ss -tlnp | grep :${PORT}"
    fi
done
ok "Порты 80 и 443 свободны"

# Обновление системы
step "Шаг 1/6: Обновление системы"
info "Обновляю список пакетов..."
apt-get update -qq
apt-get install -y -qq curl wget ca-certificates nginx
ok "Система обновлена"

# BBR
step "Шаг 2/6: Включение ускорения сети (BBR)"
info "BBR — технология Google для увеличения скорости передачи данных."

grep -qxF "net.core.default_qdisc=fq" /etc/sysctl.conf \
    || echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
grep -qxF "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf \
    || echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p -q

CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$CURRENT_CC" == "bbr" ]]; then
    ok "BBR включён"
else
    warn "BBR не применился (${CURRENT_CC}). Работает только на KVM. VPN будет работать, но чуть медленнее."
fi

# Установка S-UI
step "Шаг 3/6: Установка панели S-UI"
info "S-UI — веб-панель для управления VPN пользователями."
info "Устанавливаю S-UI... (может занять 2-3 минуты)"

bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh) 2>&1 | grep -E "(username|password|s-ui.*installation finished)" || true

# Ждём запуска S-UI
info "Жду запуска панели (до 30 секунд)..."
READY=0
for i in $(seq 1 15); do
    if curl -sf http://localhost:2095/ > /dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 2
done

if [[ $READY -ne 1 ]]; then
    warn "S-UI запускается дольше обычного. Продолжаю настройку..."
fi

ok "S-UI установлен и работает на внутреннем порту 2095"

# Настройка Nginx как reverse proxy
step "Шаг 4/6: Настройка доступа через порт 80"
info "Настраиваю Nginx для доступа к панели через стандартный HTTP порт (80)."
info "Это позволит открыть панель БЕЗ указания порта в адресе."

# Останавливаем nginx если он работает
systemctl stop nginx 2>/dev/null || true

# Создаём конфиг nginx
cat > /etc/nginx/sites-available/s-ui << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # Увеличенные таймауты для WebSocket
    proxy_connect_timeout   10s;
    proxy_send_timeout      86400s;
    proxy_read_timeout      86400s;
    
    location / {
        proxy_pass         http://127.0.0.1:2095;
        proxy_http_version 1.1;
        
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";
    }
}
EOF

# Удаляем дефолтный конфиг nginx
rm -f /etc/nginx/sites-enabled/default

# Включаем наш конфиг
ln -sf /etc/nginx/sites-available/s-ui /etc/nginx/sites-enabled/

# Проверяем конфиг
if nginx -t 2>/dev/null; then
    ok "Конфигурация Nginx валидна"
else
    fail "Ошибка в конфигурации Nginx. Проверьте логи: nginx -t"
fi

# Запускаем nginx
systemctl enable nginx --now
ok "Nginx запущен и настроен"

# Настройка файрвола
step "Шаг 5/6: Настройка файрвола"
info "Открываю порты 80 и 443 в файрволе Ubuntu..."

ufw --force enable
ufw allow 80/tcp comment 'HTTP (S-UI Panel via Nginx)'
ufw allow 443/tcp comment 'HTTPS (NaiveProxy)'

ok "Файрвол настроен"

# Проверка доступности
step "Шаг 6/6: Проверка доступности"

info "Проверяю доступность панели через порт 80..."
sleep 3

if curl -sf http://localhost:80/ > /dev/null 2>&1; then
    ok "Панель доступна через порт 80"
else
    warn "Панель не отвечает сразу. Подождите 30-60 секунд."
fi

# Получаем учётные данные из логов S-UI
CREDENTIALS=$(journalctl -u s-ui -n 50 --no-pager 2>/dev/null | grep -A2 "First admin credentials" | tail -2 || echo "")
USERNAME=$(echo "$CREDENTIALS" | grep "Username:" | awk '{print $2}' | tr -d '\n')
PASSWORD=$(echo "$CREDENTIALS" | grep "Password:" | awk '{print $2}' | tr -d '\n')

# Если не нашли в логах — показываем дефолтные
if [[ -z "$USERNAME" ]]; then
    USERNAME="admin"
    PASSWORD="admin"
    warn "Не удалось извлечь сгенерированные учётные данные. Используйте стандартные: admin / admin"
fi

# Итоговая информация
IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
    || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║           ВПН УСПЕШНО УСТАНОВЛЕН!                   ║"
echo "  ╠══════════════════════════════════════════════════════╣"
echo -e "  ║  Адрес панели:   ${BOLD}http://${IP}/app/${NC}${GREEN}${BOLD}"
echo "  ║                  (порт указывать не нужно!)          ║"
echo "  ╠══════════════════════════════════════════════════════╣"
echo "  ║  Логин:          ${USERNAME}                               "
echo "  ║  Пароль:         ${PASSWORD}                               "
echo "  ╠══════════════════════════════════════════════════════╣"
echo "  ║  ⚠️  СМЕНИТЕ ПАРОЛЬ сразу после первого входа!       ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}${BOLD}Что делать дальше:${NC}"
echo "  1. Откройте в браузере: http://${IP}/app/"
echo "  2. Войдите с учётными данными выше"
echo "  3. Сразу смените пароль (Settings → Change Password)"
echo "  4. Создайте нового пользователя VPN в разделе «Inbounds»"
echo ""
echo -e "${YELLOW}Полезные команды:${NC}"
echo "  Статус S-UI:        systemctl status s-ui"
echo "  Логи S-UI:          journalctl -u s-ui -f"
echo "  Перезапустить S-UI: systemctl restart s-ui"
echo "  Статус Nginx:       systemctl status nginx"
echo "  Перезапустить Nginx: systemctl restart nginx"
echo ""
