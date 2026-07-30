#!/usr/bin/env bash

# 未定義変数の使用や途中コマンドの失敗を検知し、
# エラー時にスクリプトを停止します。
set -euo pipefail


# ============================================================
# パッケージ基本情報
# ============================================================

# 作成するdebパッケージ名です。
PACKAGE_NAME="linux-build-lab-camera"

# 環境変数PACKAGE_VERSIONが指定されていない場合は、
# 既定値として0.1.0を使用します。
PACKAGE_VERSION="${PACKAGE_VERSION:-0.1.0}"

# 作成するdebパッケージのCPUアーキテクチャです。
# 今回はLinux x64向けのためamd64を使用します。
ARCHITECTURE="${ARCHITECTURE:-amd64}"


# ============================================================
# リポジトリ内のパス設定
# ============================================================

# このスクリプト自身が配置されているディレクトリを取得します。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# packaging/camera-deb から2階層上を
# リポジトリルートとして取得します。
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ビルド対象となる.NETプロジェクトです。
PROJECT_PATH="${REPOSITORY_ROOT}/src/LinuxBuildLab.Camera/LinuxBuildLab.Camera.csproj"

# publish後に生成されるメインDLL名です。
APPLICATION_DLL="LinuxBuildLab.Camera.dll"

# パッケージへ含めるsystemd Unitファイル名です。
SERVICE_FILE="${PACKAGE_NAME}.service"


# ============================================================
# 作業ディレクトリと出力先
# ============================================================

# debパッケージを組み立てるための一時作業ディレクトリです。
WORK_DIR="${REPOSITORY_ROOT}/artifacts/deb/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

# 完成したdebパッケージの出力先です。
OUTPUT_DIR="${REPOSITORY_ROOT}/artifacts/packages"

# GitHub Actionsなどでpublish済みの成果物を渡す場合に使用します。
# PUBLISH_DIRが未指定の場合は、カメラアプリ専用のpublish先を使用します。
PUBLISH_DIR="${PUBLISH_DIR:-${REPOSITORY_ROOT}/artifacts/publish/${PACKAGE_NAME}}"


# ============================================================
# 作業ディレクトリの初期化
# ============================================================

# 以前の作業結果が残らないように削除します。
rm -rf "${WORK_DIR}"

# debパッケージに必要なディレクトリを作成します。
mkdir -p \
  "${WORK_DIR}/DEBIAN" \
  "${WORK_DIR}/opt/${PACKAGE_NAME}" \
  "${WORK_DIR}/usr/bin" \
  "${WORK_DIR}/lib/systemd/system" \
  "${OUTPUT_DIR}"


# ============================================================
# .NETアプリのpublish
# ============================================================

# publish済みDLLが存在しない場合は、
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

# publish成果物を /opt/linux-build-lab-camera へ配置します。
cp -a \
  "${PUBLISH_DIR}/." \
  "${WORK_DIR}/opt/${PACKAGE_NAME}/"

# systemd Unitファイルを配置します。
cp \
  "${SCRIPT_DIR}/${SERVICE_FILE}" \
  "${WORK_DIR}/lib/systemd/system/${SERVICE_FILE}"


# ============================================================
# 実行用ラッパースクリプトの作成
# ============================================================

# /usr/bin/linux-build-lab-camera を作成します。
# 利用者はdotnetコマンドやDLLパスを意識せずに、
# linux-build-lab-cameraコマンドとして実行できます。
cat > "${WORK_DIR}/usr/bin/${PACKAGE_NAME}" <<'WRAPPER'
#!/usr/bin/env bash

exec /usr/bin/dotnet \
  /opt/linux-build-lab-camera/LinuxBuildLab.Camera.dll "$@"
WRAPPER

# 実行権限を付与します。
chmod 0755 "${WORK_DIR}/usr/bin/${PACKAGE_NAME}"


# ============================================================
# debパッケージ情報の作成
# ============================================================

# debパッケージのメタ情報を記述するcontrolファイルを作成します。
cat > "${WORK_DIR}/DEBIAN/control" <<CONTROL
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: utils
Priority: optional
Architecture: ${ARCHITECTURE}
Depends: dotnet-runtime-10.0, v4l-utils
Maintainer: mono-tec
Description: USB camera capture sample for Linux Build Lab
 A framework-dependent .NET application that uses v4l2-ctl to capture
 a JPEG image from a USB camera assigned to an Incus container.
CONTROL


# ============================================================
# インストール後処理
# ============================================================

# debパッケージのインストール後に実行される処理です。
# 新しいsystemd Unitを認識させるため、
# systemctl daemon-reloadを実行します。
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

# debパッケージの削除前に実行される処理です。
# systemdサービスが起動中または有効化済みでも、
# エラーにせず停止・無効化します。
cat > "${WORK_DIR}/DEBIAN/prerm" <<'PRERM'
#!/usr/bin/env bash
set -e

systemctl stop linux-build-lab-camera.service 2>/dev/null || true
systemctl disable linux-build-lab-camera.service 2>/dev/null || true

exit 0
PRERM

chmod 0755 "${WORK_DIR}/DEBIAN/prerm"


# ============================================================
# アンインストール後処理
# ============================================================

# debパッケージの削除後にsystemdの設定を再読込します。
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
# --root-owner-groupにより、
# パッケージ内の所有者をroot:rootとして扱います。
dpkg-deb \
  --build \
  --root-owner-group \
  "${WORK_DIR}" \
  "${PACKAGE_PATH}"


# 作成結果を表示します。
echo "Created: ${PACKAGE_PATH}"