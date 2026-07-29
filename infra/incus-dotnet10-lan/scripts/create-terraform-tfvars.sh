#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLE_FILE="${PROJECT_DIR}/terraform.tfvars.example"
OUTPUT_FILE="${PROJECT_DIR}/terraform.tfvars"

echo "[INFO] terraform.tfvarsを作成します。"

if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  echo "[ERROR] サンプルファイルが見つかりません: ${EXAMPLE_FILE}"
  exit 1
fi

if [[ -f "${OUTPUT_FILE}" ]]; then
  echo "[ERROR] terraform.tfvarsはすでに存在します: ${OUTPUT_FILE}"
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
  echo "[ERROR] ネットワークインターフェースが存在しません: ${LAN_INTERFACE}"
  exit 1
fi

read -r -p "Windowsで作成したSSH公開鍵ファイルのパスを入力してください: " SSH_PUBLIC_KEY_FILE

SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE/#\~/${HOME}}"

if [[ ! -f "${SSH_PUBLIC_KEY_FILE}" ]]; then
  echo "[ERROR] SSH公開鍵ファイルが見つかりません: ${SSH_PUBLIC_KEY_FILE}"
  exit 1
fi

SSH_PUBLIC_KEY="$(tr -d '\r\n' < "${SSH_PUBLIC_KEY_FILE}")"

if [[ ! "${SSH_PUBLIC_KEY}" =~ ^ssh- ]]; then
  echo "[ERROR] SSH公開鍵の形式を確認してください。"
  exit 1
fi

read -r -p "取得するReleaseバージョンを入力してください [v0.1.0]: " RELEASE_VERSION
RELEASE_VERSION="${RELEASE_VERSION:-v0.1.0}"

cp "${EXAMPLE_FILE}" "${OUTPUT_FILE}"

sed -i \
  -e "s|^lan_interface[[:space:]]*=.*|lan_interface = \"${LAN_INTERFACE}\"|" \
  -e "s|^ssh_public_key[[:space:]]*=.*|ssh_public_key = \"${SSH_PUBLIC_KEY}\"|" \
  -e "s|^release_version[[:space:]]*=.*|release_version = \"${RELEASE_VERSION}\"|" \
  "${OUTPUT_FILE}"

chmod 600 "${OUTPUT_FILE}"

echo
echo "[INFO] terraform.tfvarsを作成しました。"
echo "[INFO] 出力先: ${OUTPUT_FILE}"
echo
echo "[INFO] 設定内容を確認してください。"
echo "       nano ${OUTPUT_FILE}"