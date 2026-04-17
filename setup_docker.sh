#!/bin/bash

# 1. Ускорение сети BBR (на хосте)
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 2. Установка Docker
curl -fsSL https://get.docker.com | sh

# 3. Создание папок для базы данных и сертификатов
mkdir -p /root/s-ui/db /root/s-ui/cert

# 4. Запуск контейнера S-UI
# Пробрасываем порты: 2095 (UI), 443 (NaiveProxy), 80 (для сертификатов)
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

# 5. Итоговая информация
IP=$(curl -s https://api.ipify.org)
echo "-------------------------------------------------------"
echo "S-UI в Docker успешно запущен!"
echo "Адрес панели: http://$IP:2095/app/"
echo "Стандартный логин/пароль: admin / admin"
echo "-------------------------------------------------------"
