#!/usr/bin/env bash

# コマンド失敗、未定義変数、パイプ途中の失敗を検知します。
set -euo pipefail


# ============================================================
# パスと既定値
# ============================================================

# スクリプトが配置されているディレクトリです。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# scripts/create-terraform-tfvars.shから1階層上を
# OpenTofu構成ディレクトリとして扱います。
CONFIG_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

VARIABLES_FILE="${CONFIG_DIR}/variables.tf"
OUTPUT_FILE="${CONFIG_DIR}/terraform.tfvars"

DEFAULT_GITHUB_REPOSITORY="mono-tec/mono-sample-linux-build-lab"

# variables.tfのpackage_version既定値を取得します。
DEFAULT_PACKAGE_VERSION="$(
  sed -n '
    /variable "package_version"/,/^}/ {
      s/^[[:space:]]*default[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p
    }
  ' "${VARIABLES_FILE}"
)"

# variables.tfのpackage_name既定値を取得します。
DEFAULT_PACKAGE_NAME="$(
  sed -n '
    /variable "package_name"/,/^}/ {
      s/^[[:space:]]*default[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p
    }
  ' "${VARIABLES_FILE}"
)"

# variables.tfから既定値を取得できなかった場合は停止します。
if [[ -z "${DEFAULT_PACKAGE_VERSION}" ]]; then
  echo "[ERROR] variables.tfからpackage_versionの既定値を取得できませんでした。"
  exit 1
fi

if [[ -z "${DEFAULT_PACKAGE_NAME}" ]]; then
  echo "[ERROR] variables.tfからpackage_nameの既定値を取得できませんでした。"
  exit 1
fi


# ============================================================
# 共通関数
# ============================================================

escape_hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"

  printf '%s' "$value"
}

validate_ipv4_address() {
  local address="$1"
  local octet
  local -a octets

  if [[ ! "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 1
  fi

  IFS='.' read -r -a octets <<< "$address"

  for octet in "${octets[@]}"; do
    if ((10#$octet < 0 || 10#$octet > 255)); then
      return 1
    fi
  done

  return 0
}

validate_ipv4_prefix() {
  local prefix="$1"

  if [[ ! "$prefix" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if ((prefix < 1 || prefix > 32)); then
    return 1
  fi

  return 0
}


# ============================================================
# LAN設定
# ============================================================

echo "========================================"
echo "terraform.tfvars作成"
echo "========================================"
echo

echo "利用可能なネットワークインターフェース:"
ip -brief link show | awk '{ print "  - " $1 }'
echo

read -r -p \
  "Ubuntuホストの有線LANインターフェース名を入力してください: " \
  lan_interface

if [[ -z "${lan_interface}" ]]; then
  echo "[ERROR] ネットワークインターフェース名が入力されていません。"
  exit 1
fi

if ! ip link show "${lan_interface}" >/dev/null 2>&1; then
  echo "[ERROR] ネットワークインターフェースが見つかりません: ${lan_interface}"
  exit 1
fi

echo
echo "IPv4設定方式を選択してください。"
echo "  1: DHCP"
echo "  2: 固定IP"
echo

while true; do
  read -r -p "選択 [1/2]: " network_selection

  case "${network_selection}" in
    1)
      network_mode="dhcp"
      guest_ipv4_address=""
      guest_ipv4_prefix=24
      break
      ;;

    2)
      network_mode="static"

      while true; do
        read -r -p \
          "コンテナへ設定する固定IPv4アドレスを入力してください: " \
          guest_ipv4_address

        if validate_ipv4_address "${guest_ipv4_address}"; then
          break
        fi

        echo "[ERROR] IPv4アドレスの形式が正しくありません。"
      done

      while true; do
        read -r -p \
          "IPv4プレフィックス長を入力してください [24]: " \
          guest_ipv4_prefix

        guest_ipv4_prefix="${guest_ipv4_prefix:-24}"

        if validate_ipv4_prefix "${guest_ipv4_prefix}"; then
          break
        fi

        echo "[ERROR] プレフィックス長は1から32の範囲で入力してください。"
      done

      break
      ;;

    *)
      echo "[ERROR] 1または2を入力してください。"
      ;;
  esac
done


# ============================================================
# USBカメラ設定
# ============================================================

echo
echo "映像デバイスを確認します。"
ls -l /dev/video* 2>/dev/null || true
echo

read -r -p \
  "Ubuntuホスト側のカメラデバイス [/dev/video0]: " \
  camera_source_path

camera_source_path="${camera_source_path:-/dev/video0}"

if [[ ! -c "${camera_source_path}" ]]; then
  echo "[ERROR] カメラデバイスが見つかりません: ${camera_source_path}"
  exit 1
fi

read -r -p \
  "コンテナ内のカメラデバイス [/dev/video0]: " \
  camera_guest_path

camera_guest_path="${camera_guest_path:-/dev/video0}"

read -r -p \
  "コンテナ内videoグループのGID [44]: " \
  camera_group_id

camera_group_id="${camera_group_id:-44}"

if [[ ! "${camera_group_id}" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] camera_group_idは数値で入力してください。"
  exit 1
fi

read -r -p \
  "カメラデバイスのアクセス権限 [0660]: " \
  camera_device_mode

camera_device_mode="${camera_device_mode:-0660}"

if [[ ! "${camera_device_mode}" =~ ^0[0-7]{3}$ ]]; then
  echo "[ERROR] アクセス権限は0660のような形式で入力してください。"
  exit 1
fi


# ============================================================
# SSH公開鍵
# ============================================================

echo
echo "Windows側で作成したSSH公開鍵を入力してください。"
echo "例: ssh-ed25519 AAAA... mono-linux-build-lab"
echo

read -r -p "SSH公開鍵: " ssh_public_key

if [[ -z "${ssh_public_key}" ]]; then
  echo "[ERROR] SSH公開鍵が入力されていません。"
  exit 1
fi

if [[ ! "${ssh_public_key}" =~ ^ssh-(ed25519|rsa)[[:space:]] ]]; then
  echo "[ERROR] SSH公開鍵の形式を確認してください。"
  exit 1
fi


# ============================================================
# GitHub Releaseとdebパッケージ
# ============================================================

echo

read -r -p \
  "GitHub Repository [${DEFAULT_GITHUB_REPOSITORY}]: " \
  github_repository

github_repository="${github_repository:-${DEFAULT_GITHUB_REPOSITORY}}"

read -r -p \
  "debパッケージ名 [${DEFAULT_PACKAGE_NAME}]: " \
  package_name

package_name="${package_name:-${DEFAULT_PACKAGE_NAME}}"

read -r -p \
  "debパッケージのバージョン [${DEFAULT_PACKAGE_VERSION}]: " \
  package_version

package_version="${package_version:-${DEFAULT_PACKAGE_VERSION}}"

if [[ ! "${package_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "[ERROR] パッケージバージョンはX.Y.Z形式で入力してください。例: 0.3.1"
  exit 1
fi


# ============================================================
# HCL文字列のエスケープ
# ============================================================

escaped_lan_interface="$(escape_hcl_string "${lan_interface}")"
escaped_network_mode="$(escape_hcl_string "${network_mode}")"
escaped_guest_ipv4_address="$(escape_hcl_string "${guest_ipv4_address}")"

escaped_camera_source_path="$(escape_hcl_string "${camera_source_path}")"
escaped_camera_guest_path="$(escape_hcl_string "${camera_guest_path}")"
escaped_camera_device_mode="$(escape_hcl_string "${camera_device_mode}")"

escaped_ssh_public_key="$(escape_hcl_string "${ssh_public_key}")"

escaped_github_repository="$(escape_hcl_string "${github_repository}")"
escaped_package_name="$(escape_hcl_string "${package_name}")"
escaped_package_version="$(escape_hcl_string "${package_version}")"


# ============================================================
# terraform.tfvarsの作成
# ============================================================

cat > "${OUTPUT_FILE}" <<EOF
lan_interface = "${escaped_lan_interface}"

network_mode       = "${escaped_network_mode}"
guest_ipv4_address = "${escaped_guest_ipv4_address}"
guest_ipv4_prefix  = ${guest_ipv4_prefix}

camera_device_name = "camera0"
camera_source_path = "${escaped_camera_source_path}"
camera_guest_path  = "${escaped_camera_guest_path}"
camera_group_id    = ${camera_group_id}
camera_device_mode = "${escaped_camera_device_mode}"

ssh_public_key = "${escaped_ssh_public_key}"

github_repository = "${escaped_github_repository}"
package_name       = "${escaped_package_name}"
package_version    = "${escaped_package_version}"
EOF

chmod 600 "${OUTPUT_FILE}"

echo
echo "========================================"
echo "${OUTPUT_FILE}を作成しました。"
echo "========================================"
echo
cat "${OUTPUT_FILE}"
echo
echo "[INFO] ${OUTPUT_FILE}はGitへ登録しないでください。"