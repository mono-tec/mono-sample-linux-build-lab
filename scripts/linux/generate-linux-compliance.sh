#!/usr/bin/env bash

# ==============================================================================
# Linux向け SBOM / OSS Notice / LICENSE 生成補助スクリプト
#
# 概要:
#   .NETプロジェクトをLinux向けにpublishし、
#   Microsoft sbom-toolを使用してSPDX形式のSBOMを生成します。
#
#   生成したSBOMをONOTへ渡し、第三者OSSのライセンス情報を
#   THIRD-PARTY-NOTICES.mdとして生成します。
#
#   最後に、リポジトリ直下のLICENSEと合わせて、
#   complianceディレクトリへ以下の3ファイルをまとめます。
#
#     LICENSE
#     THIRD-PARTY-NOTICES.md
#     sbom.spdx.json
#
# ------------------------------------------------------------------------------
# ライセンスの考え方
#
#   LICENSE
#     このプロジェクト自身のライセンスです。
#
#     例:
#       MIT
#       Apache License 2.0
#       社内用Copyright / Proprietary License
#
#     本スクリプトではライセンス種別を判定しません。
#     リポジトリ直下に配置されたLICENSEをそのまま使用します。
#
#   THIRD-PARTY-NOTICES.md
#     .NET RuntimeやNuGetパッケージなど、
#     第三者OSSのライセンス情報です。
#
#     sbom-toolで生成したSBOMをONOTへ渡して生成します。
#
#   sbom.spdx.json
#     ソフトウェア構成を記録したSPDX形式のSBOMです。
#
# ------------------------------------------------------------------------------
# 想定環境:
#
#   - Ubuntu / WSL Ubuntu
#   - .NET SDK
#   - Microsoft sbom-tool
#   - ONOT
#   - Git
#
# ONOTをPython venvへインストールしている場合は、
# 本スクリプト実行前に仮想環境を有効化してください。
#
# 例:
#
#   source ~/tools/onot/.venv/bin/activate
#
# ------------------------------------------------------------------------------
# 使用方法:
#
#   ./scripts/linux/generate-linux-compliance.sh
#
# 実行すると、以下を対話形式で入力します。
#
#   1. リポジトリのパス
#   2. csprojの相対パス
#   3. パッケージ名
#   4. バージョン
#
# 例:
#
#   リポジトリ:
#     /mnt/y/github-public/sample/mono-sample-linux-build-lab
#
#   csproj:
#     src/LinuxBuildLab.Camera/LinuxBuildLab.Camera.csproj
#
#   パッケージ名:
#     linux-build-lab-camera
#
#   バージョン:
#     0.3.1
#
# ------------------------------------------------------------------------------
# 生成先:
#
#   artifacts/
#   ├── <package-name>-linux/
#   │   ├── Linux向けpublish成果物
#   │   └── _manifest/
#   │       └── spdx_2.2/
#   │           └── manifest.spdx.json
#   │
#   ├── <package-name>-license/
#   │   └── ONOT生成物
#   │
#   └── <package-name>-compliance/
#       ├── LICENSE
#       ├── THIRD-PARTY-NOTICES.md
#       └── sbom.spdx.json
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Bash実行設定
# ------------------------------------------------------------------------------
#
# -e
#   コマンドが失敗した場合にスクリプトを終了します。
#
# -u
#   未定義変数を使用した場合にエラーとします。
#
# -o pipefail
#   パイプ処理途中のエラーも検出します。
#
set -euo pipefail


# ------------------------------------------------------------------------------
# 必須コマンド確認
# ------------------------------------------------------------------------------

for command in dotnet sbom-tool onot git; do

    if ! command -v "$command" >/dev/null 2>&1; then

        echo "ERROR: '$command' コマンドが見つかりません。"
        echo

        if [[ "$command" == "onot" ]]; then
            echo "ONOTをvenvへインストールしている場合は、"
            echo "仮想環境を有効化してから再実行してください。"
            echo
            echo "例:"
            echo "  source ~/tools/onot/.venv/bin/activate"
        fi

        exit 1
    fi

done


# ------------------------------------------------------------------------------
# 入力
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " Linux SBOM / OSS Notice Generator"
echo "============================================================"
echo

read -rp "リポジトリのパスを入力してください: " REPO_DIR
read -rp "csprojの相対パスを入力してください: " PROJECT_PATH
read -rp "パッケージ名を入力してください: " PACKAGE_NAME
read -rp "バージョンを入力してください: " VERSION

echo


# ------------------------------------------------------------------------------
# 入力値整理
# ------------------------------------------------------------------------------

# リポジトリパス末尾の "/" を削除します。
REPO_DIR="${REPO_DIR%/}"

# csprojの絶対パスです。
PROJECT_FULL_PATH="$REPO_DIR/$PROJECT_PATH"

# sbom-toolのコンポーネント検索対象です。
PROJECT_DIR="$(dirname "$PROJECT_FULL_PATH")"

# プロジェクト自身のLICENSEです。
LICENSE_FILE="$REPO_DIR/LICENSE"

# Linux向けpublish成果物です。
PUBLISH_DIR="$REPO_DIR/artifacts/${PACKAGE_NAME}-linux"

# ONOTの作業用出力先です。
NOTICE_DIR="$REPO_DIR/artifacts/${PACKAGE_NAME}-license"

# 最終的に配布・パッケージングで利用するファイルをまとめます。
COMPLIANCE_DIR="$REPO_DIR/artifacts/${PACKAGE_NAME}-compliance"


# ------------------------------------------------------------------------------
# 入力チェック
# ------------------------------------------------------------------------------

if [[ ! -d "$REPO_DIR" ]]; then
    echo "ERROR: リポジトリが見つかりません。"
    echo "Path: $REPO_DIR"
    exit 1
fi


if [[ ! -f "$PROJECT_FULL_PATH" ]]; then
    echo "ERROR: csprojが見つかりません。"
    echo "Path: $PROJECT_FULL_PATH"
    exit 1
fi


if [[ ! -f "$LICENSE_FILE" ]]; then
    echo "ERROR: LICENSEファイルが見つかりません。"
    echo
    echo "リポジトリ直下にLICENSEを配置してください。"
    echo
    echo "Expected:"
    echo "  $LICENSE_FILE"
    exit 1
fi


# ------------------------------------------------------------------------------
# GitHubリポジトリURL取得
# ------------------------------------------------------------------------------
#
# SBOMのnamespaceとして使用するURLをGitのoriginから取得します。
#
# 対応例:
#
#   https://github.com/mono-tec/example.git
#
#   git@github.com:mono-tec/example.git
#
# GitHub以外でも処理自体は継続します。
#

if GIT_REMOTE_URL="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null)"; then

    if [[ "$GIT_REMOTE_URL" == git@github.com:* ]]; then

        GITHUB_PATH="${GIT_REMOTE_URL#git@github.com:}"
        GITHUB_PATH="${GITHUB_PATH%.git}"

        SBOM_NAMESPACE="https://github.com/$GITHUB_PATH"

    elif [[ "$GIT_REMOTE_URL" == https://github.com/* ]]; then

        SBOM_NAMESPACE="${GIT_REMOTE_URL%.git}"

    else

        # GitHub以外の場合はそのURLをそのまま利用します。
        SBOM_NAMESPACE="${GIT_REMOTE_URL%.git}"

    fi

else

    # Git管理されていない場合などのフォールバックです。
    SBOM_NAMESPACE="https://example.invalid/$PACKAGE_NAME"

fi


# ------------------------------------------------------------------------------
# 実行内容表示
# ------------------------------------------------------------------------------

echo "------------------------------------------------------------"
echo "Repository : $REPO_DIR"
echo "Project    : $PROJECT_FULL_PATH"
echo "Package    : $PACKAGE_NAME"
echo "Version    : $VERSION"
echo "License    : $LICENSE_FILE"
echo "Namespace  : $SBOM_NAMESPACE"
echo "------------------------------------------------------------"
echo


# ------------------------------------------------------------------------------
# 古い成果物削除
# ------------------------------------------------------------------------------
#
# 過去のWindows/Linux成果物や古いSBOMが混入しないよう、
# 今回使用する出力ディレクトリを一度削除します。
#

echo "Cleaning previous artifacts..."

rm -rf "$PUBLISH_DIR"
rm -rf "$NOTICE_DIR"
rm -rf "$COMPLIANCE_DIR"

mkdir -p "$NOTICE_DIR"
mkdir -p "$COMPLIANCE_DIR"

echo


# ------------------------------------------------------------------------------
# 1. Linux向けpublish
# ------------------------------------------------------------------------------

echo "============================================================"
echo " 1. Linux publish"
echo "============================================================"
echo

dotnet publish \
    "$PROJECT_FULL_PATH" \
    -c Release \
    -r linux-x64 \
    --self-contained false \
    -o "$PUBLISH_DIR"

echo
echo "Publish completed:"
echo "  $PUBLISH_DIR"
echo


# ------------------------------------------------------------------------------
# 2. SBOM生成
# ------------------------------------------------------------------------------
#
# -b
#   実際に配布するLinux向けpublish成果物です。
#
# -bc
#   コンポーネント・依存関係の検索対象です。
#
# -li true
#   ClearlyDefined APIからライセンス情報の取得を試みます。
#
# -pm true
#   パッケージメタデータからライセンス・Supplier情報の取得を
#   試みます。
#
# -D true
#   過去の_manifestが存在する場合は削除して再生成します。
#

echo "============================================================"
echo " 2. Generate SBOM"
echo "============================================================"
echo

sbom-tool generate \
    -b "$PUBLISH_DIR" \
    -bc "$PROJECT_DIR" \
    -pn "$PACKAGE_NAME" \
    -pv "$VERSION" \
    -ps "mono-tec" \
    -nsb "$SBOM_NAMESPACE" \
    -li true \
    -pm true \
    -D true

echo


# ------------------------------------------------------------------------------
# 3. SBOM生成確認
# ------------------------------------------------------------------------------

SBOM_PATH="$PUBLISH_DIR/_manifest/spdx_2.2/manifest.spdx.json"

if [[ ! -f "$SBOM_PATH" ]]; then

    echo "ERROR: SBOMが生成されませんでした。"
    echo
    echo "Expected:"
    echo "  $SBOM_PATH"

    exit 1

fi


echo "SBOM generated:"
echo "  $SBOM_PATH"
echo


# ------------------------------------------------------------------------------
# 4. OSS Notice生成
# ------------------------------------------------------------------------------
#
# ONOTへSPDX SBOMを渡してMarkdown形式のOSS Noticeを生成します。
#

echo "============================================================"
echo " 3. Generate OSS Notice"
echo "============================================================"
echo

onot generate \
    -i "$SBOM_PATH" \
    -f markdown \
    --output-dir "$NOTICE_DIR"

echo


# ------------------------------------------------------------------------------
# 5. ONOT生成ファイル確認
# ------------------------------------------------------------------------------

NOTICE_FILE="$(find "$NOTICE_DIR" -maxdepth 1 -type f -name "*.md" | head -n 1)"

if [[ -z "$NOTICE_FILE" ]]; then

    echo "ERROR: OSS Noticeが生成されませんでした。"
    echo
    echo "Directory:"
    echo "  $NOTICE_DIR"

    exit 1

fi


echo "OSS Notice generated:"
echo "  $NOTICE_FILE"
echo


# ------------------------------------------------------------------------------
# 6. Compliance成果物作成
# ------------------------------------------------------------------------------
#
# 最終的にdeb等へ組み込むファイルを1か所へまとめます。
#
# LICENSE
#   プロジェクト自身のライセンス
#
# THIRD-PARTY-NOTICES.md
#   第三者OSSのライセンス情報
#
# sbom.spdx.json
#   ソフトウェア構成情報
#

echo "============================================================"
echo " 4. Build compliance files"
echo "============================================================"
echo

cp "$LICENSE_FILE" \
   "$COMPLIANCE_DIR/LICENSE"

cp "$NOTICE_FILE" \
   "$COMPLIANCE_DIR/THIRD-PARTY-NOTICES.md"

cp "$SBOM_PATH" \
   "$COMPLIANCE_DIR/sbom.spdx.json"


# ------------------------------------------------------------------------------
# 7. 最終確認
# ------------------------------------------------------------------------------

echo
echo "Generated compliance files:"
echo

find "$COMPLIANCE_DIR" \
    -maxdepth 1 \
    -type f \
    -printf "  %f\n" \
    | sort

echo


# ------------------------------------------------------------------------------
# 完了
# ------------------------------------------------------------------------------

echo "============================================================"
echo " Completed"
echo "============================================================"
echo

echo "Linux publish:"
echo "  $PUBLISH_DIR"
echo

echo "SBOM:"
echo "  $COMPLIANCE_DIR/sbom.spdx.json"
echo

echo "Project LICENSE:"
echo "  $COMPLIANCE_DIR/LICENSE"
echo

echo "Third-party OSS Notice:"
echo "  $COMPLIANCE_DIR/THIRD-PARTY-NOTICES.md"
echo