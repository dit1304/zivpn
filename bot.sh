#!/bin/bash
source /etc/zivpn/bot.conf

API="https://api.telegram.org/bot$BOT_TOKEN"
DB="/etc/zivpn/users.db"
STATE="/etc/zivpn/bot.state"
OFFSET=$(cat $OFFSET_FILE 2>/dev/null)

# ===== SERVER INFO =====
VPS_IP=$(curl -s ifconfig.me)
CITY=$(curl -s ipinfo.io/city)
ISP=$(curl -s ipinfo.io/org)

# ===== UTIL =====
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
        [{"text":"➕ Add Akun","callback_data":"ADD"}],
        [{"text":"🔄 Extend Akun","callback_data":"EXT"}],
        [{"text":"❌ Hapus Akun","callback_data":"DEL"}],
        [{"text":"📋 List Akun","callback_data":"LIST"}],
        [{"text":"🌐 Add Domain","callback_data":"DOMAIN"}]
      ]
    }' >/dev/null
}

# ===== GET UPDATE =====
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
ADD)
  echo "$chat|ADD_USER|" > "$STATE"
  edit "$chat" "$msgid" "➕ *ADD AKUN*\nMasukkan *USERNAME*:"
  exit 0
;;
EXT)
  echo "$chat|EXT_USER|" > "$STATE"
  edit "$chat" "$msgid" "🔄 *EXTEND AKUN*\nMasukkan *USERNAME*:"
  exit 0
;;
DEL)
  echo "$chat|DEL_USER|" > "$STATE"
  edit "$chat" "$msgid" "❌ *HAPUS AKUN*\nMasukkan *USERNAME*:"
  exit 0
;;
LIST)
  while IFS='|' read -r u p e ip bw dom; do
    exp=$(date -d @$e)
    [[ "$dom" == "IP_ONLY" ]] && dom_out="$VPS_IP" || dom_out="$dom"
    send "$chat" "```
━━━━━━━━━━━━━━━━━━━━━
 ACCOUNT ZIVPN UDP
━━━━━━━━━━━━━━━━━━━━━
Password   : $p
CITY       : $CITY
ISP        : $ISP
IP / Domain: $dom_out
Bandwidth  : $bw
IP Limit   : $ip
Expired On : $exp
━━━━━━━━━━━━━━━━━━━━━
```"
  done < "$DB"
  exit 0
;;
DOMAIN)
  echo "$chat|SET_DOMAIN|" > "$STATE"
  edit "$chat" "$msgid" "🌐 *ADD DOMAIN*\nMasukkan *USERNAME*:"
  exit 0
;;
esac

# ===== STATE MACHINE =====
if [[ -f "$STATE" ]]; then
  IFS='|' read -r cid step a b c d < "$STATE"
  [[ "$cid" != "$chat" ]] && exit 0

  case "$step" in
  ADD_USER)
    echo "$chat|ADD_PASS|$text" > "$STATE"
    send "$chat" "🔐 Masukkan *PASSWORD*:"
  ;;
  ADD_PASS)
    echo "$chat|ADD_DAYS|$a|$text" > "$STATE"
    send "$chat" "⏱️ Masa aktif *(hari)*:"
  ;;
  ADD_DAYS)
    echo "$chat|ADD_IP|$a|$b|$text" > "$STATE"
    send "$chat" "🔒 IP Limit?\nKetik `1` atau `∞`"
  ;;
  ADD_IP)
    echo "$chat|ADD_BW|$a|$b|$c|$text" > "$STATE"
    send "$chat" "📶 Bandwidth?\n`1mbit / 2mbit / ∞`"
  ;;
  ADD_BW)
    echo "$chat|ADD_DOMAIN|$a|$b|$c|$d|$text" > "$STATE"
    send "$chat" "🌐 Pakai domain?\nKetik domain atau `no`"
  ;;
  ADD_DOMAIN)
    if [[ "$text" == "no" ]]; then
      dom="IP_ONLY"
    else
      dom="$text"
      ip_dns=$(getent hosts "$dom" | awk '{print $1}')
      [[ "$ip_dns" != "$VPS_IP" ]] && send "$chat" "❌ Domain belum pointing ke $VPS_IP" && exit 0
    fi
    exp=$(date -d "+$c days" +%s)
    echo "$a|$b|$exp|$d|$e|$dom" >> "$DB"
    bash /root/account.sh sync
    rm -f "$STATE"
    send "$chat" "✅ *AKUN BERHASIL DIBUAT*\nUser: *$a*"
    menu "$chat"
  ;;
  EXT_USER)
    echo "$chat|EXT_DAYS|$text" > "$STATE"
    send "$chat" "⏱️ Tambah berapa *hari*?"
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
  SET_DOMAIN)
    echo "$chat|DOMAIN_VAL|$text" > "$STATE"
    send "$chat" "🌐 Masukkan *DOMAIN*:"
  ;;
  DOMAIN_VAL)
    ip_dns=$(getent hosts "$text" | awk '{print $1}')
    [[ "$ip_dns" != "$VPS_IP" ]] && send "$chat" "❌ Domain belum pointing ke $VPS_IP" && exit 0
    awk -F'|' -v u="$a" -v d="$text" 'BEGIN{OFS=FS}{
      if ($1==u) $6=d; print
    }' "$DB" > /tmp/u && mv /tmp/u "$DB"
    send "$chat" "🌐 Domain *$text* berhasil dipasang"
    rm -f "$STATE"
    menu "$chat"
  ;;
  esac
fi

[[ "$text" == "/start" ]] && menu "$chat"
