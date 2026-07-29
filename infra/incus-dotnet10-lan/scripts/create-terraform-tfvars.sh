#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLE_FILE="${PROJECT_DIR}/terraform.tfvars.example"
OUTPUT_FILE="${PROJECT_DIR}/terraform.tfvars"

echo "[INFO] terraform.tfvarsを作成します。"

# terraform.tfvars.exampleの存在確認
if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  echo "[ERROR] サンプルファイルが見つかりません。"
  echo "[ERROR] ${EXAMPLE_FILE}"
  exit 1
fi

# 既存ファイルを誤って上書きしないように停止
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

# Ubuntuホストで使用する有線LANインターフェースを入力
read -r -p "有線LANインターフェース名を入力してください [eno1]: " LAN_INTERFACE
LAN_INTERFACE="${LAN_INTERFACE:-eno1}"

if [[ ! -d "/sys/class/net/${LAN_INTERFACE}" ]]; then
  echo "[ERROR] ネットワークインターフェースが存在しません。"
  echo "[ERROR] ${LAN_INTERFACE}"
  exit 1
fi

echo

# Windows側で作成したSSH公開鍵を直接入力
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

# GitHub Releasesから取得する検証アプリのバージョンを入力
read -r -p "取得する検証用 .NET 10 アプリのReleaseバージョンを入力してください [v0.1.0]: " RELEASE_VERSION
RELEASE_VERSION="${RELEASE_VERSION:-v0.1.0}"

if [[ ! "${RELEASE_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "[ERROR] 検証用 .NET 10 アプリのReleaseバージョン形式を確認してください。"
  echo "[INFO] 例: v0.1.0"
  exit 1
fi

# サンプルをコピーして、環境固有の値を書き換える
cp "${EXAMPLE_FILE}" "${OUTPUT_FILE}"

sed -i \
  -e "s|^lan_interface[[:space:]]*=.*|lan_interface = \"${LAN_INTERFACE}\"|" \
  -e "s|^ssh_public_key[[:space:]]*=.*|ssh_public_key = \"${SSH_PUBLIC_KEY}\"|" \
  -e "s|^release_version[[:space:]]*=.*|release_version = \"${RELEASE_VERSION}\"|" \
  "${OUTPUT_FILE}"

# 環境固有値を含むため、所有者だけが読み書きできるようにする
chmod 600 "${OUTPUT_FILE}"

echo
echo "[INFO] terraform.tfvarsを作成しました。"
echo "[INFO] 出力先: ${OUTPUT_FILE}"
echo
echo "[INFO] 主な設定値:"
echo "  LANインターフェース : ${LAN_INTERFACE}"
echo "  検証用アプリRelease  : ${RELEASE_VERSION}"
echo
echo "[INFO] 次のコマンドで内容を確認してください。"
echo "  cat \"${OUTPUT_FILE}\""