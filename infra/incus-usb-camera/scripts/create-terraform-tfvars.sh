#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="terraform.tfvars"

DEFAULT_GITHUB_REPOSITORY="mono-tec/mono-sample-linux-build-lab"
DEFAULT_RELEASE_VERSION="v0.2.0"

escape_hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"

  printf '%s' "$value"
}

validate_ipv4_address() {
  local address="$1"
  local octet

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

echo "========================================"
echo "terraform.tfvars作成"
echo "========================================"
echo

echo "利用可能なネットワークインターフェース:"
ip -brief link show | awk '{ print "  - " $1 }'
echo

read -r -p "Ubuntuホストの有線LANインターフェース名を入力してください: " host_lan_interface

if [[ -z "$host_lan_interface" ]]; then
  echo "[ERROR] ネットワークインターフェース名が入力されていません。"
  exit 1
fi

if ! ip link show "$host_lan_interface" >/dev/null 2>&1; then
  echo "[ERROR] ネットワークインターフェースが見つかりません: $host_lan_interface"
  exit 1
fi

echo
echo "IPv4設定方式を選択してください。"
echo "  1: DHCP"
echo "  2: 固定IP"
echo

while true; do
  read -r -p "選択 [1/2]: " network_selection

  case "$network_selection" in
    1)
      network_mode="dhcp"
      guest_ipv4_address=""
      guest_ipv4_prefix=24
      break
      ;;
    2)
      network_mode="static"

      while true; do
        read -r -p "コンテナへ設定する固定IPv4アドレスを入力してください: " guest_ipv4_address

        if validate_ipv4_address "$guest_ipv4_address"; then
          break
        fi

        echo "[ERROR] IPv4アドレスの形式が正しくありません。"
      done

      while true; do
        read -r -p "IPv4プレフィックス長を入力してください [24]: " guest_ipv4_prefix
        guest_ipv4_prefix="${guest_ipv4_prefix:-24}"

        if validate_ipv4_prefix "$guest_ipv4_prefix"; then
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

echo
echo "Windows側で作成したSSH公開鍵を入力してください。"
echo "例: ssh-ed25519 AAAA... mono-linux-build-lab"
echo

read -r -p "SSH公開鍵: " ssh_public_key

if [[ -z "$ssh_public_key" ]]; then
  echo "[ERROR] SSH公開鍵が入力されていません。"
  exit 1
fi

if [[ ! "$ssh_public_key" =~ ^ssh-(ed25519|rsa)[[:space:]] ]]; then
  echo "[ERROR] SSH公開鍵の形式を確認してください。"
  exit 1
fi

echo
read -r -p \
  "GitHub Repository [${DEFAULT_GITHUB_REPOSITORY}]: " \
  github_repository

github_repository="${github_repository:-$DEFAULT_GITHUB_REPOSITORY}"

read -r -p \
  "debパッケージのReleaseバージョン [${DEFAULT_RELEASE_VERSION}]: " \
  release_version

release_version="${release_version:-$DEFAULT_RELEASE_VERSION}"

if [[ ! "$release_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "[ERROR] Releaseバージョンはv0.2.0のような形式で入力してください。"
  exit 1
fi

escaped_host_lan_interface="$(escape_hcl_string "$host_lan_interface")"
escaped_network_mode="$(escape_hcl_string "$network_mode")"
escaped_guest_ipv4_address="$(escape_hcl_string "$guest_ipv4_address")"
escaped_ssh_public_key="$(escape_hcl_string "$ssh_public_key")"
escaped_github_repository="$(escape_hcl_string "$github_repository")"
escaped_release_version="$(escape_hcl_string "$release_version")"

cat > "$OUTPUT_FILE" <<EOF
host_lan_interface = "${escaped_host_lan_interface}"

network_mode       = "${escaped_network_mode}"
guest_ipv4_address = "${escaped_guest_ipv4_address}"
guest_ipv4_prefix  = ${guest_ipv4_prefix}

ssh_public_key = "${escaped_ssh_public_key}"

github_repository = "${escaped_github_repository}"
release_version   = "${escaped_release_version}"
EOF

chmod 600 "$OUTPUT_FILE"

echo
echo "========================================"
echo "${OUTPUT_FILE}を作成しました。"
echo "========================================"
echo
cat "$OUTPUT_FILE"
echo
echo "[INFO] ${OUTPUT_FILE}はGitへ登録しないでください。"