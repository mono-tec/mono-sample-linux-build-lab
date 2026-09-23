#!/usr/bin/env bash

# コマンド失敗時、未定義変数使用時、パイプ途中の失敗時に
# スクリプトを終了します。
set -euo pipefail


# ============================================================
# パッケージ基本情報
# ============================================================

# 作成するdebパッケージ名です。
PACKAGE_NAME="linux-build-lab-sample"

# 環境変数PACKAGE_VERSIONが指定されていない場合に使用する
# 既定のパッケージバージョンです。
PACKAGE_VERSION="${PACKAGE_VERSION:-0.2.0}"

# Linux x64向けパッケージのため、Debianのアーキテクチャ名として
# amd64を使用します。
ARCHITECTURE="${ARCHITECTURE:-amd64}"


# ============================================================
# リポジトリ内のパス設定
# ============================================================

# このスクリプトが配置されているディレクトリを取得します。
#
# 想定配置:
# packaging/sample-deb/build-deb.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# packaging/sample-debから2階層上を
# リポジトリルートとして取得します。
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# パッケージ化する.NETプロジェクトです。
PROJECT_PATH="${REPOSITORY_ROOT}/src/LinuxBuildLab.Sample/LinuxBuildLab.Sample.csproj"

# publish後に生成されるメインDLLです。
APPLICATION_DLL="LinuxBuildLab.Sample.dll"

# パッケージへ含めるsystemd Unitファイルです。
SERVICE_FILE="${PACKAGE_NAME}.service"


# ============================================================
# 作業ディレクトリと出力先
# ============================================================

# debパッケージを組み立てる一時作業ディレクトリです。
WORK_DIR="${REPOSITORY_ROOT}/artifacts/deb/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

# 完成したdebパッケージの出力先です。
OUTPUT_DIR="${REPOSITORY_ROOT}/artifacts/packages"

# GitHub Actionsなどでpublish済みの成果物を渡す場合に使用します。
#
# PUBLISH_DIRが指定されていない場合は、
# sampleアプリ専用のpublishディレクトリを使用します。
#
# カメラアプリの成果物と混在しないように、
# アプリごとにディレクトリを分離しています。
PUBLISH_DIR="${PUBLISH_DIR:-${REPOSITORY_ROOT}/artifacts/publish/${PACKAGE_NAME}}"

# GitHub Actionsなどで生成した
# ライセンス・Notice・SBOMを配置したディレクトリです。
#
# 想定内容:
#   LICENSE
#   THIRD-PARTY-NOTICES.md
#   sbom.spdx.json
COMPLIANCE_DIR="${COMPLIANCE_DIR:-${REPOSITORY_ROOT}/artifacts/compliance/${PACKAGE_NAME}}"


# ============================================================
# 作業ディレクトリの初期化
# ============================================================

# 前回の作業結果が残らないように削除します。
rm -rf "${WORK_DIR}"

# debパッケージ内で使用するディレクトリを作成します。
mkdir -p \
  "${WORK_DIR}/DEBIAN" \
  "${WORK_DIR}/opt/${PACKAGE_NAME}" \
  "${WORK_DIR}/usr/bin" \
  "${WORK_DIR}/usr/share/doc/${PACKAGE_NAME}" \
  "${WORK_DIR}/lib/systemd/system" \
  "${OUTPUT_DIR}"


# ============================================================
# .NETアプリのpublish
# ============================================================

# GitHub Actionsなどからpublish済み成果物が渡されていない場合は、
# このスクリプト内でdotnet publishを実行します。
if [[ ! -f "${PUBLISH_DIR}/${APPLICATION_DLL}" ]]; then
  rm -rf "${PUBLISH_DIR}"

  dotnet publish "${PROJECT_PATH}" \
    --configuration Release \
    --runtime linux-x64 \
    --self-contained false \
    --output "${PUBLISH_DIR}" \
    -p:Version="${PACKAGE_VERSION}"
fi


# ============================================================
# アプリ本体とsystemd Unitの配置
# ============================================================

# publish成果物を次の場所へ配置します。
#
# /opt/linux-build-lab-sample
cp -a \
  "${PUBLISH_DIR}/." \
  "${WORK_DIR}/opt/${PACKAGE_NAME}/"

# systemd Unitファイルを配置します。
#
# /lib/systemd/system/linux-build-lab-sample.service
cp \
  "${SCRIPT_DIR}/${SERVICE_FILE}" \
  "${WORK_DIR}/lib/systemd/system/${SERVICE_FILE}"


# ============================================================
# ライセンス・Notice・SBOMの配置
# ============================================================

# プロジェクト自身のライセンスを配置します。
#
# /usr/share/doc/linux-build-lab-sample/LICENSE
cp \
  "${COMPLIANCE_DIR}/LICENSE" \
  "${WORK_DIR}/usr/share/doc/${PACKAGE_NAME}/LICENSE"

# 依存OSSのライセンス情報を配置します。
#
# /usr/share/doc/linux-build-lab-sample/THIRD-PARTY-NOTICES.md
cp \
  "${COMPLIANCE_DIR}/THIRD-PARTY-NOTICES.md" \
  "${WORK_DIR}/usr/share/doc/${PACKAGE_NAME}/THIRD-PARTY-NOTICES.md"

# SPDX形式のSBOMを配置します。
#
# /usr/share/doc/linux-build-lab-sample/sbom.spdx.json
cp \
  "${COMPLIANCE_DIR}/sbom.spdx.json" \
  "${WORK_DIR}/usr/share/doc/${PACKAGE_NAME}/sbom.spdx.json"


# ============================================================
# 実行用ラッパースクリプトの作成
# ============================================================

# /usr/bin/linux-build-lab-sampleを作成します。
#
# 利用者はDLLの配置先を意識せず、
# linux-build-lab-sampleコマンドとして実行できます。
cat > "${WORK_DIR}/usr/bin/${PACKAGE_NAME}" <<'WRAPPER'
#!/usr/bin/env bash

exec /usr/bin/dotnet \
  /opt/linux-build-lab-sample/LinuxBuildLab.Sample.dll "$@"
WRAPPER

# ラッパースクリプトへ実行権限を付与します。
chmod 0755 "${WORK_DIR}/usr/bin/${PACKAGE_NAME}"


# ============================================================
# debパッケージ情報の作成
# ============================================================

# Debianパッケージのメタ情報を記載する
# controlファイルを作成します。
cat > "${WORK_DIR}/DEBIAN/control" <<CONTROL
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: utils
Priority: optional
Architecture: ${ARCHITECTURE}
Depends: dotnet-runtime-10.0
Maintainer: mono-tec
Description: One-shot .NET sample package for Linux Build Lab
 A framework-dependent .NET application used to verify Debian package
 creation, installation, systemd execution, and removal.
CONTROL


# ============================================================
# インストール後処理
# ============================================================

# debパッケージのインストール後に実行されます。
#
# パッケージに含まれるsystemd Unitを認識させるため、
# systemdの設定を再読込します。
cat > "${WORK_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/usr/bin/env bash
set -e

systemctl daemon-reload || true

exit 0
POSTINST

chmod 0755 "${WORK_DIR}/DEBIAN/postinst"


# ============================================================
# アンインストール前処理
# ============================================================

# debパッケージの削除前に実行されます。
#
# サービスが起動中または有効化済みの場合に備えて、
# 停止と無効化を行います。
cat > "${WORK_DIR}/DEBIAN/prerm" <<'PRERM'
#!/usr/bin/env bash
set -e

systemctl stop linux-build-lab-sample.service 2>/dev/null || true
systemctl disable linux-build-lab-sample.service 2>/dev/null || true

exit 0
PRERM

chmod 0755 "${WORK_DIR}/DEBIAN/prerm"


# ============================================================
# アンインストール後処理
# ============================================================

# debパッケージの削除後に実行されます。
#
# Unitファイルの削除をsystemdへ反映するため、
# systemdの設定を再読込します。
cat > "${WORK_DIR}/DEBIAN/postrm" <<'POSTRM'
#!/usr/bin/env bash
set -e

systemctl daemon-reload || true

exit 0
POSTRM

chmod 0755 "${WORK_DIR}/DEBIAN/postrm"


# ============================================================
# debパッケージの作成
# ============================================================

# 完成するdebパッケージのファイルパスです。
PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"

# 作業ディレクトリを元にdebパッケージを作成します。
#
# --root-owner-groupを指定することで、
# パッケージ内のファイル所有者をroot:rootとして扱います。
dpkg-deb \
  --build \
  --root-owner-group \
  "${WORK_DIR}" \
  "${PACKAGE_PATH}"


# 作成されたdebパッケージのパスを表示します。
echo "Created: ${PACKAGE_PATH}"