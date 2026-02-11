#!/bin/bash

DB="/etc/zivpn/users.db"
CFG="/etc/zivpn/config.json"
NOW=$(date +%s)

# ===== FUNCTION: SYNC CONFIG =====
sync_config() {
  # reset config password list
  jq '.config=[]' "$CFG" > /tmp/z && mv /tmp/z "$CFG"

  while IFS='|' read -r user pass exp; do
    [[ -z "$user" ]] && continue
    [[ "$exp" -le "$NOW" ]] && continue

    jq ".config += [\"$pass\"]" "$CFG" > /tmp/z && mv /tmp/z "$CFG"
  done < "$DB"

  systemctl restart zivpn
}

# ===== MAIN =====
case "$1" in

add)
  read -p "Username : " user
  read -p "Password : " pass
  read -p "Masa aktif (hari): " days

  if [[ -z "$user" || -z "$pass" || -z "$days" ]]; then
    echo "❌ Input tidak lengkap"
    exit 1
  fi

  if grep -q "^$user|" "$DB"; then
    echo "❌ Username sudah ada"
    exit 1
  fi

  exp=$(date -d "+$days days" +%s)
  echo "$user|$pass|$exp" >> "$DB"

  sync_config
  echo "✅ Akun $user ditambahkan (expire: $(date -d @$exp))"
;;

del)
  read -p "Username : " user

  if ! grep -q "^$user|" "$DB"; then
    echo "❌ Username tidak ditemukan"
    exit 1
  fi

  grep -v "^$user|" "$DB" > /tmp/u && mv /tmp/u "$DB"

  sync_config
  echo "🗑️ Akun $user dihapus"
;;

list)
  echo "========================================"
  echo "USERNAME | EXPIRE"
  echo "----------------------------------------"

  while IFS='|' read -r user pass exp; do
    [[ -z "$user" ]] && continue
    if [[ "$exp" -le "$NOW" ]]; then
      status="EXPIRED"
    else
      status=$(date -d @$exp)
    fi
    printf "%-10s | %s\n" "$user" "$status"
  done < "$DB"

  echo "========================================"
;;

sync)
  sync_config
;;

*)
  echo "Usage:"
  echo "  bash account.sh add    # tambah akun"
  echo "  bash account.sh del    # hapus akun"
  echo "  bash account.sh list   # lihat akun"
  echo "  bash account.sh sync   # sinkron config"
;;

esac
