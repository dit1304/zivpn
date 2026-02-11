#!/bin/bash

DB="/etc/zivpn/users.db"
CFG="/etc/zivpn/config.json"
NOW=$(date +%s)

sync_config() {
  jq '.config=[]' "$CFG" > /tmp/z && mv /tmp/z "$CFG"
  while IFS='|' read -r u p e; do
    [[ -z "$u" ]] && continue
    [[ "$e" -le "$NOW" ]] && continue
    jq ".config += [\"$p\"]" "$CFG" > /tmp/z && mv /tmp/z "$CFG"
  done < "$DB"
  systemctl restart zivpn
}

case "$1" in
add)
  read -p "Username : " u
  read -p "Password : " p
  read -p "Masa aktif (hari): " d
  exp=$(date -d "+$d days" +%s)
  echo "$u|$p|$exp" >> "$DB"
  sync_config
  echo "✅ Akun $u dibuat"
;;
del)
  read -p "Username : " u
  grep -v "^$u|" "$DB" > /tmp/u && mv /tmp/u "$DB"
  sync_config
  echo "🗑️ Akun $u dihapus"
;;
list)
  echo "USER | EXPIRE"
  while IFS='|' read -r u p e; do
    echo "$u | $(date -d @$e)"
  done < "$DB"
;;
sync)
  sync_config
;;
*)
  echo "Usage: add | del | list | sync"
;;
esac
