#!/bin/bash
source /etc/zivpn/bot.conf
DB="/etc/zivpn/users.db"
TMP="/tmp/u.tmp"
NOW=$(date +%s)

send() {
 curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
 -d chat_id="$ADMIN_ID" \
 -d text="$1" >/dev/null
}

> $TMP
while IFS='|' read -r u p e; do
  if [[ $e -le $NOW ]]; then
    send "⛔ Akun $u EXPIRED"
  else
    echo "$u|$p|$e" >> $TMP
  fi
done < $DB

mv $TMP $DB
bash /root/account.sh sync
