#!/usr/bin/env bash

# エラー発生時、未定義変数の使用時、
# パイプ途中のコマンド失敗時にスクリプトを終了する。
set -euo pipefail

# このスクリプトが配置されているディレクトリを取得する。
# どのカレントディレクトリから実行しても、
# プロジェクト内の相対位置を正しく解決できるようにする。
readonly SCRIPT_DIRECTORY="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

# scriptsディレクトリの1つ上をプロジェクトルートとして取得する。
readonly PROJECT_DIRECTORY="$(
  cd "${SCRIPT_DIRECTORY}/.." &&
    pwd
)"

# 検証用テンプレートの格納先。
# request.mdと役割別プロンプトを含む。
readonly TEMPLATE_DIRECTORY="${PROJECT_DIRECTORY}/hello-dotnet"

# Ubuntuホスト上で検証ごとの成果物を保存するルートディレクトリ。
readonly EXPERIMENT_ROOT="/home/ubuntu/ai-agent-team/experiments"

# 第1引数から検証IDを取得する。
# 例：experiment-001
EXPERIMENT_ID="${1:-}"

# 検証IDが指定されていない場合は、
# 使用方法を表示して終了する。
if [[ -z "${EXPERIMENT_ID}" ]]; then
  echo "Usage: $0 <experiment-id>"
  echo "Example: $0 experiment-001"
  exit 1
fi

# 今回作成する検証ディレクトリの絶対パス。
readonly EXPERIMENT_DIRECTORY="${EXPERIMENT_ROOT}/${EXPERIMENT_ID}"

# テンプレートディレクトリが存在することを確認する。
if [[ ! -d "${TEMPLATE_DIRECTORY}" ]]; then
  echo "[ERROR] Template directory was not found."
  echo "[ERROR] Expected path: ${TEMPLATE_DIRECTORY}"
  exit 1
fi

# 同じ検証IDのディレクトリがすでに存在する場合は、
# 既存成果物を上書きしないように終了する。
if [[ -e "${EXPERIMENT_DIRECTORY}" ]]; then
  echo "[ERROR] Experiment already exists."
  echo "[ERROR] Path: ${EXPERIMENT_DIRECTORY}"
  exit 1
fi

echo "[INFO] Creating experiment directory."

# 検証用ディレクトリを作成する。
mkdir -p "${EXPERIMENT_DIRECTORY}"

echo "[INFO] Copying experiment template."

# request.mdとpromptsディレクトリを、
# リポジトリ内のテンプレートから検証領域へコピーする。
cp -a \
  "${TEMPLATE_DIRECTORY}/." \
  "${EXPERIMENT_DIRECTORY}/"

echo "[INFO] Creating output directories."

# AIエージェントが設計書、ソースコード、
# テストコード、実行結果を保存するディレクトリを作成する。
mkdir -p \
  "${EXPERIMENT_DIRECTORY}/documents" \
  "${EXPERIMENT_DIRECTORY}/src" \
  "${EXPERIMENT_DIRECTORY}/tests" \
  "${EXPERIMENT_DIRECTORY}/reports" \
  "${EXPERIMENT_DIRECTORY}/logs" \
  "${EXPERIMENT_DIRECTORY}/status"

echo "[INFO] Experiment created."

# Ubuntuホスト側の保存先を表示する。
echo "[INFO] Host path:"
echo "       ${EXPERIMENT_DIRECTORY}"

# Incusコンテナ側から参照するパスを表示する。
echo "[INFO] Container path:"
echo "       /workspace/experiments/${EXPERIMENT_ID}"