#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLE_FILE="${PROJECT_DIR}/terraform.tfvars.example"
OUTPUT_FILE="${PROJECT_DIR}/terraform.tfvars"

echo "[INFO] PostgreSQL Lab用 terraform.tfvarsを作成します。"

if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  echo "[ERROR] サンプルファイルが見つかりません。"
  exit 1
fi

if [[ -f "${OUTPUT_FILE}" ]]; then
  echo "[ERROR] terraform.tfvarsはすでに存在します。"
  echo "[INFO] 既存設定を上書きしないため、処理を終了します。"
  exit 1
fi

echo
echo "[INFO] 利用可能なネットワークインターフェース:"
ip -br address
echo

read -r -p "有線LANインターフェース名 [eno1]: " LAN_INTERFACE
LAN_INTERFACE="${LAN_INTERFACE:-eno1}"

if [[ ! -d "/sys/class/net/${LAN_INTERFACE}" ]]; then
  echo "[ERROR] ネットワークインターフェースが存在しません: ${LAN_INTERFACE}"
  exit 1
fi

echo
read -r -p "IPv4設定方式 [dhcp/static] [dhcp]: " NETWORK_MODE
NETWORK_MODE="${NETWORK_MODE:-dhcp}"

if [[ "${NETWORK_MODE}" != "dhcp" && "${NETWORK_MODE}" != "static" ]]; then
  echo "[ERROR] dhcpまたはstaticを指定してください。"
  exit 1
fi

GUEST_IPV4_ADDRESS=""
GUEST_IPV4_PREFIX="24"

if [[ "${NETWORK_MODE}" == "static" ]]; then
  read -r -p "コンテナのLAN側固定IPv4アドレス: " GUEST_IPV4_ADDRESS
  if [[ -z "${GUEST_IPV4_ADDRESS}" ]]; then
    echo "[ERROR] 固定IPv4アドレスは必須です。"
    exit 1
  fi

  read -r -p "IPv4プレフィックス長 [24]: " GUEST_IPV4_PREFIX
  GUEST_IPV4_PREFIX="${GUEST_IPV4_PREFIX:-24}"
fi

echo
read -r -p "DBeaver/PLCから接続を許可するCIDR [192.168.1.0/24]: " DB_CLIENT_CIDR
DB_CLIENT_CIDR="${DB_CLIENT_CIDR:-192.168.1.0/24}"

read -r -p "データベース名 [labdb]: " DB_NAME
DB_NAME="${DB_NAME:-labdb}"

read -r -p "データベースユーザー名 [labuser]: " DB_USER
DB_USER="${DB_USER:-labuser}"

read -r -s -p "データベースパスワード（12文字以上、英数字_-のみ）: " DB_PASSWORD
echo

if [[ ${#DB_PASSWORD} -lt 12 || ! "${DB_PASSWORD}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "[ERROR] パスワードは12文字以上、英数字・_・-のみで指定してください。"
  exit 1
fi

cp "${EXAMPLE_FILE}" "${OUTPUT_FILE}"

sed -i \
  -e "s|^lan_interface[[:space:]]*=.*|lan_interface = \"${LAN_INTERFACE}\"|" \
  -e "s|^network_mode[[:space:]]*=.*|network_mode = \"${NETWORK_MODE}\"|" \
  -e "s|^guest_ipv4_address[[:space:]]*=.*|guest_ipv4_address = \"${GUEST_IPV4_ADDRESS}\"|" \
  -e "s|^guest_ipv4_prefix[[:space:]]*=.*|guest_ipv4_prefix = ${GUEST_IPV4_PREFIX}|" \
  -e "s|^db_name[[:space:]]*=.*|db_name = \"${DB_NAME}\"|" \
  -e "s|^db_user[[:space:]]*=.*|db_user = \"${DB_USER}\"|" \
  -e "s|^db_password[[:space:]]*=.*|db_password = \"${DB_PASSWORD}\"|" \
  -e "s|^db_client_cidr[[:space:]]*=.*|db_client_cidr = \"${DB_CLIENT_CIDR}\"|" \
  "${OUTPUT_FILE}"

chmod 600 "${OUTPUT_FILE}"

echo
echo "[INFO] terraform.tfvarsを作成しました。"
echo "[INFO] 出力先: ${OUTPUT_FILE}"
echo "[INFO] DB名: ${DB_NAME}"
echo "[INFO] DBユーザー: ${DB_USER}"
echo "[INFO] 接続許可CIDR: ${DB_CLIENT_CIDR}"
