#!/bin/bash
source /etc/zivpn/bot.conf

API="https://api.telegram.org/bot$BOT_TOKEN"
DB="/etc/zivpn/users.db"
STATE="/etc/zivpn/bot.state"
OFFSET=$(cat $OFFSET_FILE 2>/dev/null)

DOMAIN="free.premium.idrastore.biz.id"
BANDWIDTH="∞"
IP_LIMIT="∞"

IP=$(curl -s ifconfig.me)
CITY=$(curl -s ipinfo.io/city)
ISP=$(curl -s ipinfo.io/org)

send() {
  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$1" \
    -d parse_mode="Markdown" \
    -d text="$2" >/dev/null
}

edit() {
  curl -s -X POST "$API/editMessageText" \
    -d chat_id="$1" \
    -d message_id="$2" \
    -d parse_mode="Markdown" \
    -d text="$3" >/dev/null
}

menu() {
  curl -s -X POST "$API/sendMessage" \
    -d chat_id="$1" \
    -d parse_mode="Markdown" \
    -d text="📡 *ZIVPN UDP MANAGER*" \
    -d reply_markup='{
      "inline_keyboard":[
        [{"text":"➕ Add Akun","callback_data":"add"}],
        [{"text":"🔄 Extend Akun","callback_data":"extend"}],
        [{"text":"❌ Hapus Akun","callback_data":"del"}],
        [{"text":"📋 List Akun","callback_data":"list"}],
        [{"text":"ℹ️ Info Server","callback_data":"info"}]
      ]
    }' >/dev/null
}

res=$(curl -s "$API/getUpdates?offset=$OFFSET")
uid=$(echo "$res" | jq '.result[-1].update_id')
[[ -z "$uid" ]] && exit 0
echo $((uid+1)) > $OFFSET_FILE

chat=$(echo "$res" | jq -r '.result[-1].message.chat.id // .result[-1].callback_query.message.chat.id')
from=$(echo "$res" | jq -r '.result[-1].message.from.id // .result[-1].callback_query.from.id')
text=$(echo "$res" | jq -r '.result[-1].message.text // .result[-1].callback_query.data')
msgid=$(echo "$res" | jq -r '.result[-1].callback_query.message.message_id // empty')

[[ "$from" != "$ADMIN_ID" ]] && exit 0

# ===== CALLBACK MENU =====
case "$text" in
add)
  echo "$chat|ADD_USER|" > "$STATE"
  edit "$chat" "$msgid" "➕ *ADD AKUN*\n\nMasukkan *USERNAME*:"
  exit 0
;;
extend)
  echo "$chat|EXT_USER|" > "$STATE"
  edit "$chat" "$msgid" "🔄 *EXTEND AKUN*\n\nMasukkan *USERNAME*:"
  exit 0
;;
del)
  echo "$chat|DEL_USER|" > "$STATE"
  edit "$chat" "$msgid" "❌ *HAPUS AKUN*\n\nMasukkan *USERNAME*:"
  exit 0
;;
list)
  while IFS='|' read -r u p e; do
    exp=$(date -d @$e)
    send "$chat" "```
━━━━━━━━━━━━━━━━━━━━━
 ACCOUNT ZIVPN UDP
━━━━━━━━━━━━━━━━━━━━━
Password   : $p
CITY       : $CITY
ISP        : $ISP
IP ISP     : $IP
Domain     : $DOMAIN
Bandwidth  : $BANDWIDTH
IP Limit   : $IP_LIMIT
Expired On : $exp
━━━━━━━━━━━━━━━━━━━━━
```"
  done < "$DB"
  exit 0
;;
info)
  send "$chat" "*SERVER INFO*\nIP: \`$IP\`\nCITY: $CITY\nISP: $ISP"
  exit 0
;;
esac

# ===== STATE MACHINE =====
if [[ -f "$STATE" ]]; then
  IFS='|' read -r cid step a b < "$STATE"
  [[ "$cid" != "$chat" ]] && exit 0

  case "$step" in
  ADD_USER)
    echo "$chat|ADD_PASS|$text" > "$STATE"
    send "$chat" "🔐 Masukkan *PASSWORD*:"
  ;;
  ADD_PASS)
    echo "$chat|ADD_DAYS|$a|$text" > "$STATE"
    send "$chat" "⏱️ Masukkan *MASA AKTIF* (hari):"
  ;;
  ADD_DAYS)
    exp=$(date -d "+$text days" +%s)
    echo "$a|$b|$exp" >> "$DB"
    bash /root/account.sh sync
    rm -f "$STATE"
    send "$chat" "✅ *AKUN BERHASIL DIBUAT*\nUser: *$a*\nAktif: *$text hari*"
    menu "$chat"
  ;;
  EXT_USER)
    echo "$chat|EXT_DAYS|$text" > "$STATE"
    send "$chat" "⏱️ Tambah *BERAPA HARI*?"
  ;;
  EXT_DAYS)
    awk -F'|' -v u="$a" -v d="$text" 'BEGIN{OFS=FS}{
      if ($1==u) $3+=d*86400; print
    }' "$DB" > /tmp/u && mv /tmp/u "$DB"
    bash /root/account.sh sync
    rm -f "$STATE"
    send "$chat" "🔄 Akun *$a* diperpanjang *$text hari*"
    menu "$chat"
  ;;
  DEL_USER)
    grep -v "^$text|" "$DB" > /tmp/u && mv /tmp/u "$DB"
    bash /root/account.sh sync
    rm -f "$STATE"
    send "$chat" "❌ Akun *$text* dihapus"
    menu "$chat"
  ;;
  esac
fi

# ===== START =====
[[ "$text" == "/start" ]] && menu "$chat"
