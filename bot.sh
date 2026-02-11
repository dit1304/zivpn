#!/bin/bash

source /etc/zivpn/bot.conf
API="https://api.telegram.org/bot$BOT_TOKEN"
DB="/etc/zivpn/users.db"
OFFSET=$(cat $OFFSET_FILE 2>/dev/null)

send_msg() {
  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$ADMIN_ID" \
    -d text="$1" >/dev/null
}

resp=$(curl -s "$API/getUpdates?timeout=10&offset=$OFFSET")
last_id=$(echo "$resp" | jq '.result[-1].update_id')

[[ -z "$last_id" ]] && exit 0
echo $((last_id+1)) > $OFFSET_FILE

msg=$(echo "$resp" | jq -r '.result[-1].message.text')
from=$(echo "$resp" | jq -r '.result[-1].message.from.id')

[[ "$from" != "$ADMIN_ID" ]] && exit 0

case "$msg" in
/add*)
  read _ u p d <<< "$msg"
  exp=$(date -d "+$d days" +%s)
  echo "$u|$p|$exp" >> $DB
  bash /root/account.sh sync
  send_msg "✅ Akun $u ditambahkan ($d hari)"
;;
 /del*)
  read _ u <<< "$msg"
  grep -v "^$u|" $DB > /tmp/u && mv /tmp/u $DB
  bash /root/account.sh sync
  send_msg "🗑️ Akun $u dihapus"
;;
 /list)
  text="👥 AKUN ZIVPN\n"
  while IFS='|' read -r u p e; do
    text+="$u | $(date -d @$e)\n"
  done < $DB
  send_msg "$text"
;;
 /info)
  send_msg "📌 Command:\n/add user pass hari\n/del user\n/list"
;;
esac
