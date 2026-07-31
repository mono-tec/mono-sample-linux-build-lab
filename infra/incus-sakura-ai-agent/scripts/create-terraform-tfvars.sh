#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# パスと既定値
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT_FILE="${PROJECT_DIR}/terraform.tfvars"

DEFAULT_INSTANCE_NAME="ubuntu2404-sakura-ai-agent"
DEFAULT_IMAGE="images:ubuntu/24.04/cloud"
DEFAULT_CPU_COUNT="2"
DEFAULT_MEMORY_LIMIT="4GiB"

DEFAULT_LAN_DEVICE_NAME="lan0"
DEFAULT_GUEST_INTERFACE_NAME="eth1"
DEFAULT_IPV4_PREFIX="24"

DEFAULT_SAKURA_AI_BASE_URL="https://api.ai.sakura.ad.jp/v1"
DEFAULT_SAKURA_AI_MODEL="preview/Kimi-K2.7-Code"
DEFAULT_WORKSPACE_DIRECTORY="/home/ubuntu/workspace"

# ============================================================
# 共通関数
# ============================================================

escape_hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"

  printf '%s' "${value}"
}

validate_positive_integer() {
  local value="$1"

  [[ "${value}" =~ ^[1-9][0-9]*$ ]]
}

validate_memory_limit() {
  local value="$1"

  [[ "${value}" =~ ^[1-9][0-9]*(MiB|GiB)$ ]]
}

validate_ipv4_address() {
  local address="$1"
  local octet
  local -a octets

  if [[ ! "${address}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 1
  fi

  IFS='.' read -r -a octets <<< "${address}"

  for octet in "${octets[@]}"; do
    if ((10#${octet} > 255)); then
      return 1
    fi
  done

  return 0
}

validate_ipv4_prefix() {
  local prefix="$1"

  if [[ ! "${prefix}" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  ((prefix >= 1 && prefix <= 32))
}

validate_ssh_public_key() {
  local value="$1"

  [[ "${value}" =~ ^ssh-(ed25519|rsa|ecdsa)[[:space:]]+ ]]
}

show_network_interfaces() {
  echo "利用可能なネットワークインターフェース:"
  echo

  ip -brief link show |
    awk '{ print "  - " $1 }'

  echo
}

# ============================================================
# 開始
# ============================================================

echo "============================================================"
echo "Linux Build Lab"
echo "OpenCode + Sakura AI Engine terraform.tfvars作成"
echo "============================================================"
echo

# ============================================================
# Incusコンテナ設定
# ============================================================

read -r -p \
  "Incusコンテナ名 [${DEFAULT_INSTANCE_NAME}]: " \
  instance_name

instance_name="${instance_name:-${DEFAULT_INSTANCE_NAME}}"

while true; do
  read -r -p \
    "仮想CPU数 [${DEFAULT_CPU_COUNT}]: " \
    cpu_count

  cpu_count="${cpu_count:-${DEFAULT_CPU_COUNT}}"

  if validate_positive_integer "${cpu_count}"; then
    break
  fi

  echo "[ERROR] 仮想CPU数は1以上の整数で入力してください。"
done

while true; do
  read -r -p \
    "メモリ上限 [${DEFAULT_MEMORY_LIMIT}]: " \
    memory_limit

  memory_limit="${memory_limit:-${DEFAULT_MEMORY_LIMIT}}"

  if validate_memory_limit "${memory_limit}"; then
    break
  fi

  echo "[ERROR] メモリ上限は4GiBや2048MiBの形式で入力してください。"
done

# ============================================================
# LAN接続設定
# ============================================================

echo
show_network_interfaces

while true; do
  read -r -p \
    "Ubuntuホストの物理LANインターフェース名: " \
    lan_interface

  if [[ -z "${lan_interface}" ]]; then
    echo "[ERROR] LANインターフェース名を入力してください。"
    continue
  fi

  if ! ip link show "${lan_interface}" >/dev/null 2>&1; then
    echo "[ERROR] インターフェースが見つかりません: ${lan_interface}"
    continue
  fi

  break
done

echo
echo "コンテナのIPv4設定方式を選択してください。"
echo
echo "  1: DHCP"
echo "  2: 固定IPv4アドレス"
echo

while true; do
  read -r -p "選択 [1/2]: " network_selection

  case "${network_selection}" in
    1)
      network_mode="dhcp"
      guest_ipv4_address=""
      guest_ipv4_prefix="${DEFAULT_IPV4_PREFIX}"
      break
      ;;

    2)
      network_mode="static"

      while true; do
        read -r -p \
          "コンテナへ設定する固定IPv4アドレス: " \
          guest_ipv4_address

        if validate_ipv4_address "${guest_ipv4_address}"; then
          break
        fi

        echo "[ERROR] IPv4アドレスの形式が正しくありません。"
      done

      while true; do
        read -r -p \
          "IPv4プレフィックス長 [${DEFAULT_IPV4_PREFIX}]: " \
          guest_ipv4_prefix

        guest_ipv4_prefix="${guest_ipv4_prefix:-${DEFAULT_IPV4_PREFIX}}"

        if validate_ipv4_prefix "${guest_ipv4_prefix}"; then
          break
        fi

        echo "[ERROR] プレフィックス長は1から32で入力してください。"
      done

      break
      ;;

    *)
      echo "[ERROR] 1または2を入力してください。"
      ;;
  esac
done

# ============================================================
# SSH公開鍵設定
# ============================================================

echo
echo "Windows側などで作成したSSH公開鍵を入力してください。"
echo "秘密鍵は入力しないでください。"
echo
echo "例:"
echo "ssh-ed25519 AAAAC3... mono-linux-build-lab"
echo

while true; do
  read -r -p "SSH公開鍵: " ssh_public_key

  if validate_ssh_public_key "${ssh_public_key}"; then
    break
  fi

  echo "[ERROR] OpenSSH形式の公開鍵を入力してください。"
done

# ============================================================
# さくらのAI Engine設定
# ============================================================

echo
read -r -p \
  "さくらのAI Engine Base URL [${DEFAULT_SAKURA_AI_BASE_URL}]: " \
  sakura_ai_base_url

sakura_ai_base_url="${sakura_ai_base_url:-${DEFAULT_SAKURA_AI_BASE_URL}}"

if [[ ! "${sakura_ai_base_url}" =~ ^https:// ]]; then
  echo "[ERROR] Base URLはhttps://から始まる必要があります。"
  exit 1
fi

echo
read -r -s -p \
  "さくらのAI Engineアカウントトークン: " \
  sakura_ai_token

echo

if [[ -z "${sakura_ai_token}" ]]; then
  echo "[ERROR] アカウントトークンが入力されていません。"
  exit 1
fi

echo
echo "使用するモデルを選択してください。"
echo
echo "  1: preview/Kimi-K2.7-Code"
echo "  2: gpt-oss-120b"
echo "  3: llm-jp-3.1-8x13b-instruct4"
echo "  4: preview/Kimi-K2.6"
echo

while true; do
  read -r -p "選択 [1]: " model_selection

  model_selection="${model_selection:-1}"

  case "${model_selection}" in
    1)
      sakura_ai_model="preview/Kimi-K2.7-Code"
      break
      ;;

    2)
      sakura_ai_model="gpt-oss-120b"
      break
      ;;

    3)
      sakura_ai_model="llm-jp-3.1-8x13b-instruct4"
      break
      ;;

    4)
      sakura_ai_model="preview/Kimi-K2.6"
      break
      ;;

    *)
      echo "[ERROR] 1から4のいずれかを入力してください。"
      ;;
  esac
done
# ============================================================
# OpenCode作業ディレクトリ
# ============================================================

echo
read -r -p \
  "OpenCode作業ディレクトリ [${DEFAULT_WORKSPACE_DIRECTORY}]: " \
  workspace_directory

workspace_directory="${workspace_directory:-${DEFAULT_WORKSPACE_DIRECTORY}}"

if [[ ! "${workspace_directory}" == /home/ubuntu/* ]]; then
  echo "[ERROR] 作業ディレクトリは/home/ubuntu配下にしてください。"
  exit 1
fi

if [[ "${workspace_directory}" == *"/../"* ]] ||
   [[ "${workspace_directory}" == *"/.." ]]; then
  echo "[ERROR] 作業ディレクトリに..は使用できません。"
  exit 1
fi

# ============================================================
# 入力内容の確認
# ============================================================

echo
echo "============================================================"
echo "入力内容"
echo "============================================================"
echo
echo "Incusコンテナ名       : ${instance_name}"
echo "イメージ              : ${DEFAULT_IMAGE}"
echo "仮想CPU数             : ${cpu_count}"
echo "メモリ上限            : ${memory_limit}"
echo "LANインターフェース   : ${lan_interface}"
echo "IPv4設定方式          : ${network_mode}"

if [[ "${network_mode}" == "static" ]]; then
  echo "固定IPv4アドレス      : ${guest_ipv4_address}"
  echo "IPv4プレフィックス    : ${guest_ipv4_prefix}"
fi

echo "AI Engine Base URL    : ${sakura_ai_base_url}"
echo "AI Engineモデル       : ${sakura_ai_model}"
echo "作業ディレクトリ      : ${workspace_directory}"
echo "SSH公開鍵             : 入力済み"
echo "AI Engineトークン     : 入力済み"
echo

read -r -p \
  "この内容でterraform.tfvarsを作成しますか？ [Y/n]: " \
  confirmation

confirmation="${confirmation:-Y}"

case "${confirmation}" in
  Y | y)
    ;;
  *)
    echo "[INFO] 処理を中止しました。"
    unset sakura_ai_token
    exit 0
    ;;
esac

# ============================================================
# HCL文字列のエスケープ
# ============================================================

escaped_instance_name="$(
  escape_hcl_string "${instance_name}"
)"

escaped_memory_limit="$(
  escape_hcl_string "${memory_limit}"
)"

escaped_lan_interface="$(
  escape_hcl_string "${lan_interface}"
)"

escaped_network_mode="$(
  escape_hcl_string "${network_mode}"
)"

escaped_guest_ipv4_address="$(
  escape_hcl_string "${guest_ipv4_address}"
)"

escaped_ssh_public_key="$(
  escape_hcl_string "${ssh_public_key}"
)"

escaped_sakura_ai_base_url="$(
  escape_hcl_string "${sakura_ai_base_url}"
)"

escaped_sakura_ai_token="$(
  escape_hcl_string "${sakura_ai_token}"
)"

escaped_sakura_ai_model="$(
  escape_hcl_string "${sakura_ai_model}"
)"

escaped_workspace_directory="$(
  escape_hcl_string "${workspace_directory}"
)"

# ============================================================
# terraform.tfvars作成
# ============================================================

umask 077

cat > "${OUTPUT_FILE}" <<EOF
# ============================================================
# Linux Build Lab
# OpenCode + Sakura AI Engine
#
# This file is generated by:
# scripts/create-terraform-tfvars.sh
#
# Do not commit this file to Git.
# ============================================================

instance_name = "${escaped_instance_name}"
image         = "${DEFAULT_IMAGE}"

cpu_count    = ${cpu_count}
memory_limit = "${escaped_memory_limit}"

lan_device_name      = "${DEFAULT_LAN_DEVICE_NAME}"
lan_interface        = "${escaped_lan_interface}"
guest_interface_name = "${DEFAULT_GUEST_INTERFACE_NAME}"

network_mode       = "${escaped_network_mode}"
guest_ipv4_address = "${escaped_guest_ipv4_address}"
guest_ipv4_prefix  = ${guest_ipv4_prefix}

ssh_public_key = "${escaped_ssh_public_key}"

sakura_ai_base_url = "${escaped_sakura_ai_base_url}"
sakura_ai_token    = "${escaped_sakura_ai_token}"
sakura_ai_model    = "${escaped_sakura_ai_model}"

workspace_directory = "${escaped_workspace_directory}"
EOF

chmod 600 "${OUTPUT_FILE}"

unset sakura_ai_token
unset escaped_sakura_ai_token

echo
echo "============================================================"
echo "terraform.tfvarsを作成しました。"
echo "============================================================"
echo
echo "出力先:"
echo "${OUTPUT_FILE}"
echo
echo "[INFO] APIトークンを含むため、ファイル内容は表示しません。"
echo "[INFO] terraform.tfvarsをGitへ登録しないでください。"