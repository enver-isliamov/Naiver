#!/bin/bash

# 1. Обновление системы
apt update && apt upgrade -y
apt install -y curl wget sudo

# 2. Включение ускорения BBR (для быстрой работы прокси)
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 3. Установка панели S-UI (поддерживает NaiveProxy через sing-box)
# Мы используем официальный скрипт установки S-UI
bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)

# 4. Вывод данных для входа
IP=$(curl -s https://api.ipify.org)
echo "-------------------------------------------------------"
echo "Установка завершена!"
echo "Адрес панели: http://$IP:2095/app/"
echo "Стандартный логин: admin"
echo "Стандартный пароль: admin"
echo "-------------------------------------------------------"
echo "Внимание: После входа ОБЯЗАТЕЛЬНО смените пароль в настройках."
