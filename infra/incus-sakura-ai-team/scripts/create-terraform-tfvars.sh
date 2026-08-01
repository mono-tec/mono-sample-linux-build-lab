#!/usr/bin/env bash

# エラー発生時、未定義変数の使用時、
# パイプ途中のコマンド失敗時に処理を終了する。
set -euo pipefail

# ============================================================
# パスと既定値
# ============================================================

# このスクリプトが配置されているディレクトリ。
readonly SCRIPT_DIRECTORY="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

# scriptsディレクトリの1つ上をプロジェクトルートとする。
readonly PROJECT_DIRECTORY="$(
  cd "${SCRIPT_DIRECTORY}/.." &&
    pwd
)"

# terraform.tfvarsの出力先。
readonly OUTPUT_FILE="${PROJECT_DIRECTORY}/terraform.tfvars"

# Incus共通設定。
readonly DEFAULT_IMAGE="images:ubuntu/24.04/cloud"

# AIエージェント01の既定値。
readonly DEFAULT_AGENT01_INSTANCE_NAME="ubuntu2404-sakura-agent-01"
readonly DEFAULT_AGENT01_ROLE="design"
readonly DEFAULT_AGENT01_CPU_COUNT="1"
readonly DEFAULT_AGENT01_MEMORY_LIMIT="2GiB"
readonly DEFAULT_AGENT01_INSTALL_DOTNET_SDK="false"

# AIエージェント02の既定値。
readonly DEFAULT_AGENT02_INSTANCE_NAME="ubuntu2404-sakura-agent-02"
readonly DEFAULT_AGENT02_ROLE="build"
readonly DEFAULT_AGENT02_CPU_COUNT="2"
readonly DEFAULT_AGENT02_MEMORY_LIMIT="4GiB"
readonly DEFAULT_AGENT02_INSTALL_DOTNET_SDK="true"

# さくらのAI Engine設定。
readonly DEFAULT_SAKURA_AI_BASE_URL="https://api.ai.sakura.ad.jp/v1"
readonly DEFAULT_SAKURA_AI_MODEL="preview/Kimi-K2.6"

# 共有作業領域。
readonly DEFAULT_EXPERIMENT_ROOT="/home/ubuntu/ai-agent-team"
readonly DEFAULT_CONTAINER_WORKSPACE_PATH="/workspace"

# ============================================================
# 共通関数
# ============================================================

# HCLの文字列として安全に出力できるようにエスケープする。
escape_hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"

  printf '%s' "${value}"
}

# 1以上の整数であることを確認する。
validate_positive_integer() {
  local value="$1"

  [[ "${value}" =~ ^[1-9][0-9]*$ ]]
}

# Incusのメモリ上限として利用する形式を確認する。
validate_memory_limit() {
  local value="$1"

  [[ "${value}" =~ ^[1-9][0-9]*(MiB|GiB)$ ]]
}

# 絶対パスであり、ルートディレクトリそのものではないことを確認する。
validate_absolute_path() {
  local value="$1"

  [[ "${value}" == /* ]] &&
    [[ "${value}" != "/" ]] &&
    [[ "${value}" != *"/../"* ]] &&
    [[ "${value}" != *"/.." ]]
}

# trueまたはfalseであることを確認する。
validate_boolean() {
  local value="$1"

  [[ "${value}" == "true" || "${value}" == "false" ]]
}

# ============================================================
# 開始
# ============================================================

echo "============================================================"
echo "Linux Build Lab"
echo "OpenCode + Sakura AI Engine"
echo "AIエージェントチーム terraform.tfvars作成"
echo "============================================================"
echo

# ============================================================
# AIエージェント01
# ============================================================

echo "AIエージェント01を設定します。"
echo
echo "入力例:"
echo "  コンテナ名 : ubuntu2404-sakura-agent-01"
echo "  役割       : design"
echo "  仮想CPU数  : 1"
echo "  メモリ上限 : 2GiB"
echo "  .NET SDK   : false"
echo

read -r -p \
  "コンテナ名 [${DEFAULT_AGENT01_INSTANCE_NAME}]: " \
  agent01_instance_name

agent01_instance_name="${agent01_instance_name:-${DEFAULT_AGENT01_INSTANCE_NAME}}"

read -r -p \
  "役割（例: design / build / test / review） [${DEFAULT_AGENT01_ROLE}]: " \
  agent01_role

agent01_role="${agent01_role:-${DEFAULT_AGENT01_ROLE}}"

while true; do
  read -r -p \
    "仮想CPU数（1以上の整数） [${DEFAULT_AGENT01_CPU_COUNT}]: " \
    agent01_cpu_count

  agent01_cpu_count="${agent01_cpu_count:-${DEFAULT_AGENT01_CPU_COUNT}}"

  if validate_positive_integer "${agent01_cpu_count}"; then
    break
  fi

  echo "[ERROR] 仮想CPU数は1以上の整数で入力してください。"
  echo "        例: 1、2、4"
done

while true; do
  read -r -p \
    "メモリ上限（MiBまたはGiB） [${DEFAULT_AGENT01_MEMORY_LIMIT}]: " \
    agent01_memory_limit

  agent01_memory_limit="${agent01_memory_limit:-${DEFAULT_AGENT01_MEMORY_LIMIT}}"

  if validate_memory_limit "${agent01_memory_limit}"; then
    break
  fi

  echo "[ERROR] メモリ上限はMiBまたはGiB形式で入力してください。"
  echo "        例: 2048MiB、2GiB、4GiB"
done

while true; do
  read -r -p \
    ".NET 10 SDKを導入するか（true / false） [${DEFAULT_AGENT01_INSTALL_DOTNET_SDK}]: " \
    agent01_install_dotnet_sdk

  agent01_install_dotnet_sdk="${agent01_install_dotnet_sdk:-${DEFAULT_AGENT01_INSTALL_DOTNET_SDK}}"

  if validate_boolean "${agent01_install_dotnet_sdk}"; then
    break
  fi

  echo "[ERROR] trueまたはfalseを入力してください。"
done

# ============================================================
# AIエージェント02
# ============================================================

echo
echo "AIエージェント02を設定します。"
echo
echo "入力例:"
echo "  コンテナ名 : ubuntu2404-sakura-agent-02"
echo "  役割       : build"
echo "  仮想CPU数  : 2"
echo "  メモリ上限 : 4GiB"
echo "  .NET SDK   : true"
echo

read -r -p \
  "コンテナ名 [${DEFAULT_AGENT02_INSTANCE_NAME}]: " \
  agent02_instance_name

agent02_instance_name="${agent02_instance_name:-${DEFAULT_AGENT02_INSTANCE_NAME}}"

read -r -p \
  "役割（例: design / build / test / review） [${DEFAULT_AGENT02_ROLE}]: " \
  agent02_role

agent02_role="${agent02_role:-${DEFAULT_AGENT02_ROLE}}"

while true; do
  read -r -p \
    "仮想CPU数（1以上の整数） [${DEFAULT_AGENT02_CPU_COUNT}]: " \
    agent02_cpu_count

  agent02_cpu_count="${agent02_cpu_count:-${DEFAULT_AGENT02_CPU_COUNT}}"

  if validate_positive_integer "${agent02_cpu_count}"; then
    break
  fi

  echo "[ERROR] 仮想CPU数は1以上の整数で入力してください。"
  echo "        例: 1、2、4"
done

while true; do
  read -r -p \
    "メモリ上限（MiBまたはGiB） [${DEFAULT_AGENT02_MEMORY_LIMIT}]: " \
    agent02_memory_limit

  agent02_memory_limit="${agent02_memory_limit:-${DEFAULT_AGENT02_MEMORY_LIMIT}}"

  if validate_memory_limit "${agent02_memory_limit}"; then
    break
  fi

  echo "[ERROR] メモリ上限はMiBまたはGiB形式で入力してください。"
  echo "        例: 2048MiB、4GiB、8GiB"
done

while true; do
  read -r -p \
    ".NET 10 SDKを導入するか（true / false） [${DEFAULT_AGENT02_INSTALL_DOTNET_SDK}]: " \
    agent02_install_dotnet_sdk

  agent02_install_dotnet_sdk="${agent02_install_dotnet_sdk:-${DEFAULT_AGENT02_INSTALL_DOTNET_SDK}}"

  if validate_boolean "${agent02_install_dotnet_sdk}"; then
    break
  fi

  echo "[ERROR] trueまたはfalseを入力してください。"
done

# コンテナ名の重複を確認する。
if [[ "${agent01_instance_name}" == "${agent02_instance_name}" ]]; then
  echo "[ERROR] AIエージェントのコンテナ名が重複しています。"
  echo "        agent01: ${agent01_instance_name}"
  echo "        agent02: ${agent02_instance_name}"
  exit 1
fi
# コンテナ名の重複を確認する。
if [[ "${agent01_instance_name}" == "${agent02_instance_name}" ]]; then
  echo "[ERROR] AIエージェントのコンテナ名が重複しています。"
  exit 1
fi

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

read -r -p \
  "使用するモデル [${DEFAULT_SAKURA_AI_MODEL}]: " \
  sakura_ai_model

sakura_ai_model="${sakura_ai_model:-${DEFAULT_SAKURA_AI_MODEL}}"

if [[ -z "${sakura_ai_model}" ]]; then
  echo "[ERROR] モデル名を入力してください。"
  exit 1
fi

# ============================================================
# 共有作業領域
# ============================================================

echo

while true; do
  read -r -p \
    "Ubuntuホストの共有作業領域 [${DEFAULT_EXPERIMENT_ROOT}]: " \
    experiment_root

  experiment_root="${experiment_root:-${DEFAULT_EXPERIMENT_ROOT}}"

  if validate_absolute_path "${experiment_root}"; then
    break
  fi

  echo "[ERROR] ルート以外の絶対パスを入力してください。"
done

while true; do
  read -r -p \
    "コンテナ内の共有マウント先 [${DEFAULT_CONTAINER_WORKSPACE_PATH}]: " \
    container_workspace_path

   container_workspace_path="${container_workspace_path:-${DEFAULT_CONTAINER_WORKSPACE_PATH}}"

  if validate_absolute_path "${container_workspace_path}"; then
    break
  fi

  echo "[ERROR] ルート以外の絶対パスを入力してください。"
done

# ============================================================
# 入力内容の確認
# ============================================================

echo
echo "============================================================"
echo "入力内容"
echo "============================================================"
echo
echo "イメージ:"
echo "  ${DEFAULT_IMAGE}"
echo
echo "AIエージェント01:"
echo "  コンテナ名          : ${agent01_instance_name}"
echo "  役割                : ${agent01_role}"
echo "  仮想CPU数           : ${agent01_cpu_count}"
echo "  メモリ上限          : ${agent01_memory_limit}"
echo "  .NET 10 SDK         : ${agent01_install_dotnet_sdk}"
echo
echo "AIエージェント02:"
echo "  コンテナ名          : ${agent02_instance_name}"
echo "  役割                : ${agent02_role}"
echo "  仮想CPU数           : ${agent02_cpu_count}"
echo "  メモリ上限          : ${agent02_memory_limit}"
echo "  .NET 10 SDK         : ${agent02_install_dotnet_sdk}"
echo
echo "AI Engine Base URL    : ${sakura_ai_base_url}"
echo "AI Engineモデル       : ${sakura_ai_model}"
echo "AI Engineトークン     : 入力済み"
echo
echo "ホスト共有作業領域    : ${experiment_root}"
echo "コンテナマウント先    : ${container_workspace_path}"
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

escaped_agent01_instance_name="$(
  escape_hcl_string "${agent01_instance_name}"
)"

escaped_agent01_role="$(
  escape_hcl_string "${agent01_role}"
)"

escaped_agent01_memory_limit="$(
  escape_hcl_string "${agent01_memory_limit}"
)"

escaped_agent02_instance_name="$(
  escape_hcl_string "${agent02_instance_name}"
)"

escaped_agent02_role="$(
  escape_hcl_string "${agent02_role}"
)"

escaped_agent02_memory_limit="$(
  escape_hcl_string "${agent02_memory_limit}"
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

escaped_experiment_root="$(
  escape_hcl_string "${experiment_root}"
)"

escaped_container_workspace_path="$(
  escape_hcl_string "${container_workspace_path}"
)"

# ============================================================
# terraform.tfvars作成
# ============================================================

# 作成するファイルを実行ユーザーだけが読み書きできるようにする。
umask 077

cat > "${OUTPUT_FILE}" <<EOF
# ============================================================
# Linux Build Lab
# OpenCode + Sakura AI Engine
# Role-based AI Agent Team
#
# This file is generated by:
# scripts/create-terraform-tfvars.sh
#
# Do not commit this file to Git.
# ============================================================

image = "${DEFAULT_IMAGE}"

agents = {
  agent01 = {
    instance_name      = "${escaped_agent01_instance_name}"
    role               = "${escaped_agent01_role}"
    cpu_count          = ${agent01_cpu_count}
    memory_limit       = "${escaped_agent01_memory_limit}"
    install_dotnet_sdk = ${agent01_install_dotnet_sdk}
  }

  agent02 = {
    instance_name      = "${escaped_agent02_instance_name}"
    role               = "${escaped_agent02_role}"
    cpu_count          = ${agent02_cpu_count}
    memory_limit       = "${escaped_agent02_memory_limit}"
    install_dotnet_sdk = ${agent02_install_dotnet_sdk}
  }
}

sakura_ai_base_url = "${escaped_sakura_ai_base_url}"
sakura_ai_token    = "${escaped_sakura_ai_token}"
sakura_ai_model    = "${escaped_sakura_ai_model}"

experiment_root          = "${escaped_experiment_root}"
container_workspace_path = "${escaped_container_workspace_path}"
EOF

chmod 600 "${OUTPUT_FILE}"

# シェル変数内に残ったトークン情報を削除する。
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