#!/bin/bash
source /etc/zivpn/bot.conf
API="https://api.telegram.org/bot$BOT_TOKEN"
DB="/etc/zivpn/users.db"
OFFSET=$(cat $OFFSET_FILE 2>/dev/null)

send() {
  curl -s -X POST "$API/sendMessage" \
  -d chat_id="$ADMIN_ID" \
  -d text="$1" >/dev/null
}

res=$(curl -s "$API/getUpdates?offset=$OFFSET")
uid=$(echo "$res" | jq '.result[-1].update_id')
[[ -z "$uid" ]] && exit 0
echo $((uid+1)) > $OFFSET_FILE

msg=$(echo "$res" | jq -r '.result[-1].message.text')
from=$(echo "$res" | jq -r '.result[-1].message.from.id')
[[ "$from" != "$ADMIN_ID" ]] && exit 0

case "$msg" in
/add*)
  read _ u p d <<< "$msg"
  exp=$(date -d "+$d days" +%s)
  echo "$u|$p|$exp" >> $DB
  bash /root/account.sh sync
  send "✅ Akun $u aktif $d hari"
;;
 /del*)
  read _ u <<< "$msg"
  grep -v "^$u|" $DB > /tmp/u && mv /tmp/u $DB
  bash /root/account.sh sync
  send "🗑️ Akun $u dihapus"
;;
 /extend*)
  read _ u d <<< "$msg"
  awk -F'|' -v u="$u" -v d="$d" 'BEGIN{OFS=FS}{
    if ($1==u) $3+=d*86400; print
  }' $DB > /tmp/u && mv /tmp/u $DB
  bash /root/account.sh sync
  send "🔄 Akun $u diperpanjang $d hari"
;;
 /list)
  t="USER ZIVPN\n"
  while IFS='|' read -r u p e; do
    t+="$u | $(date -d @$e)\n"
  done < $DB
  send "$t"
;;
*)
  send "/add u p d\n/del u\n/extend u d\n/list"
;;
esac
