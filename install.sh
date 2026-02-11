#!/bin/bash
set -e

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ Hanya support x86_64 (AMD/Intel)"
  exit 1
fi

echo "=== INSTALL ZIVPN UDP ==="

apt update -y
apt install -y wget curl jq cron ufw iptables-persistent openssl

# Download binary
wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 \
-O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

# Folder & database
mkdir -p /etc/zivpn
touch /etc/zivpn/users.db
touch /etc/zivpn/ip.db

# Config
wget https://raw.githubusercontent.com/dit1304/zivpn/main/config.json \
-O /etc/zivpn/config.json

# Generate cert
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/C=ID/O=ZIVPN/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt

# Service
cat <<EOF >/etc/systemd/system/zivpn.service
[Unit]
Description=Zivpn UDP Server
After=network.target

[Service]
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

# Firewall
ufw allow 6000:19999/udp
ufw allow 5667/udp
ufw --force enable
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to :5667
netfilter-persistent save

# Scripts
wget https://raw.githubusercontent.com/dit1304/zivpn/main/account.sh -O /root/account.sh
wget https://raw.githubusercontent.com/dit1304/zivpn/main/bot.sh -O /root/bot.sh
wget https://raw.githubusercontent.com/dit1304/zivpn/main/cron-expire.sh -O /usr/local/bin/zivpn-expire

chmod +x /root/account.sh /root/bot.sh /usr/local/bin/zivpn-expire

echo "✅ INSTALL SELESAI"
echo "👉 Jangan lupa isi bot.conf di /etc/zivpn/"
