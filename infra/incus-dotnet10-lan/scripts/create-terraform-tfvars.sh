#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLE_FILE="${PROJECT_DIR}/terraform.tfvars.example"
OUTPUT_FILE="${PROJECT_DIR}/terraform.tfvars"

echo "[INFO] terraform.tfvarsを作成します。"

if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  echo "[ERROR] サンプルファイルが見つかりません。"
  echo "[ERROR] ${EXAMPLE_FILE}"
  exit 1
fi

if [[ -f "${OUTPUT_FILE}" ]]; then
  echo "[ERROR] terraform.tfvarsはすでに存在します。"
  echo "[ERROR] ${OUTPUT_FILE}"
  echo "[INFO] 既存設定を上書きしないため、処理を終了します。"
  exit 1
fi

echo
echo "[INFO] 利用可能なネットワークインターフェース:"
ip -br address
echo

read -r -p "有線LANインターフェース名を入力してください [eno1]: " LAN_INTERFACE
LAN_INTERFACE="${LAN_INTERFACE:-eno1}"

if [[ ! -d "/sys/class/net/${LAN_INTERFACE}" ]]; then
  echo "[ERROR] ネットワークインターフェースが存在しません。"
  echo "[ERROR] ${LAN_INTERFACE}"
  exit 1
fi

echo

read -r -p "IPv4設定方式を選択してください [dhcp/static] [dhcp]: " NETWORK_MODE
NETWORK_MODE="${NETWORK_MODE:-dhcp}"

if [[ "${NETWORK_MODE}" != "dhcp" && "${NETWORK_MODE}" != "static" ]]; then
  echo "[ERROR] IPv4設定方式はdhcpまたはstaticを指定してください。"
  exit 1
fi

echo

GUEST_IPV4_ADDRESS=""
GUEST_IPV4_PREFIX="24"

if [[ "${NETWORK_MODE}" == "static" ]]; then
  echo

  read -r -p "コンテナのLAN側固定IPv4アドレスを入力してください: " GUEST_IPV4_ADDRESS

  if [[ -z "${GUEST_IPV4_ADDRESS}" ]]; then
    echo "[ERROR] staticを選択した場合、固定IPv4アドレスは必須です。"
    exit 1
  fi

  if [[ ! "${GUEST_IPV4_ADDRESS}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "[ERROR] IPv4アドレスの形式を確認してください。"
    echo "[INFO] 例: 192.168.XXX.XXX"
    exit 1
  fi

  IFS='.' read -r -a IPV4_OCTETS <<< "${GUEST_IPV4_ADDRESS}"

  for OCTET in "${IPV4_OCTETS[@]}"; do
    if (( 10#${OCTET} < 0 || 10#${OCTET} > 255 )); then
      echo "[ERROR] IPv4アドレスの各値は0～255で指定してください。"
      exit 1
    fi
  done

  read -r -p "IPv4プレフィックス長を入力してください [24]: " GUEST_IPV4_PREFIX
  GUEST_IPV4_PREFIX="${GUEST_IPV4_PREFIX:-24}"

  if [[ ! "${GUEST_IPV4_PREFIX}" =~ ^[0-9]+$ ]] ||
     (( GUEST_IPV4_PREFIX < 1 || GUEST_IPV4_PREFIX > 32 )); then
    echo "[ERROR] IPv4プレフィックス長は1～32で指定してください。"
    exit 1
  fi
fi

echo

read -r -p "Windowsで作成したSSH公開鍵を1行で貼り付けてください: " SSH_PUBLIC_KEY

if [[ -z "${SSH_PUBLIC_KEY}" ]]; then
  echo "[ERROR] SSH公開鍵が入力されていません。"
  exit 1
fi

if [[ ! "${SSH_PUBLIC_KEY}" =~ ^ssh-(ed25519|rsa|ecdsa)[[:space:]]+ ]]; then
  echo "[ERROR] SSH公開鍵の形式を確認してください。"
  echo "[INFO] 例: ssh-ed25519 AAAAC3... mono-linux-build-lab"
  exit 1
fi

echo

read -r -p "取得する検証用 .NET 10 アプリのReleaseバージョンを入力してください [v0.1.0]: " RELEASE_VERSION
RELEASE_VERSION="${RELEASE_VERSION:-v0.1.0}"

if [[ ! "${RELEASE_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "[ERROR] 検証用 .NET 10 アプリのReleaseバージョン形式を確認してください。"
  echo "[INFO] 例: v0.1.0"
  exit 1
fi

cp "${EXAMPLE_FILE}" "${OUTPUT_FILE}"

sed -i \
  -e "s|^lan_interface[[:space:]]*=.*|lan_interface = \"${LAN_INTERFACE}\"|" \
  -e "s|^network_mode[[:space:]]*=.*|network_mode = \"${NETWORK_MODE}\"|" \
  -e "s|^guest_ipv4_address[[:space:]]*=.*|guest_ipv4_address = \"${GUEST_IPV4_ADDRESS}\"|" \
  -e "s|^guest_ipv4_prefix[[:space:]]*=.*|guest_ipv4_prefix = ${GUEST_IPV4_PREFIX}|" \
  -e "s|^ssh_public_key[[:space:]]*=.*|ssh_public_key = \"${SSH_PUBLIC_KEY}\"|" \
  -e "s|^release_version[[:space:]]*=.*|release_version = \"${RELEASE_VERSION}\"|" \
  "${OUTPUT_FILE}"

chmod 600 "${OUTPUT_FILE}"

echo
echo "[INFO] terraform.tfvarsを作成しました。"
echo "[INFO] 出力先: ${OUTPUT_FILE}"
echo
echo "[INFO] 主な設定値:"
echo "  LANインターフェース : ${LAN_INTERFACE}"
echo "  IPv4設定方式         : ${NETWORK_MODE}"

if [[ "${NETWORK_MODE}" == "static" ]]; then
  echo "  LAN側固定IPv4        : ${GUEST_IPV4_ADDRESS}/${GUEST_IPV4_PREFIX}"
fi

echo "  検証用アプリRelease  : ${RELEASE_VERSION}"
echo
echo "[INFO] 次のコマンドで内容を確認してください。"
echo "  cat \"${OUTPUT_FILE}\""