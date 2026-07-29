#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="linux-build-lab-sample"
PACKAGE_VERSION="${PACKAGE_VERSION:-1.0.0}"
ARCHITECTURE="${ARCHITECTURE:-amd64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_PATH="${REPOSITORY_ROOT}/src/LinuxBuildLab.Sample/LinuxBuildLab.Sample.csproj"

WORK_DIR="${REPOSITORY_ROOT}/artifacts/deb/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
OUTPUT_DIR="${REPOSITORY_ROOT}/artifacts/packages"

# GitHub Actionsなどでpublish済みの成果物を渡せます。
# 未指定の場合は、このスクリプト内でdotnet publishを実行します。
PUBLISH_DIR="${PUBLISH_DIR:-${REPOSITORY_ROOT}/artifacts/publish}"

rm -rf "${WORK_DIR}"
mkdir -p \
  "${WORK_DIR}/DEBIAN" \
  "${WORK_DIR}/opt/${PACKAGE_NAME}" \
  "${WORK_DIR}/usr/bin" \
  "${WORK_DIR}/lib/systemd/system" \
  "${OUTPUT_DIR}"

if [[ ! -f "${PUBLISH_DIR}/LinuxBuildLab.Sample.dll" ]]; then
  rm -rf "${PUBLISH_DIR}"

  dotnet publish "${PROJECT_PATH}" \
    --configuration Release \
    --runtime linux-x64 \
    --self-contained false \
    --output "${PUBLISH_DIR}" \
    -p:Version="${PACKAGE_VERSION}"
fi

cp -a "${PUBLISH_DIR}/." "${WORK_DIR}/opt/${PACKAGE_NAME}/"

cp "${SCRIPT_DIR}/linux-build-lab-sample.service" \
  "${WORK_DIR}/lib/systemd/system/${PACKAGE_NAME}.service"

cat > "${WORK_DIR}/usr/bin/${PACKAGE_NAME}" <<'WRAPPER'
#!/usr/bin/env bash
exec /usr/bin/dotnet \
  /opt/linux-build-lab-sample/LinuxBuildLab.Sample.dll "$@"
WRAPPER
chmod 0755 "${WORK_DIR}/usr/bin/${PACKAGE_NAME}"

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

cat > "${WORK_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/usr/bin/env bash
set -e
systemctl daemon-reload || true
exit 0
POSTINST
chmod 0755 "${WORK_DIR}/DEBIAN/postinst"

cat > "${WORK_DIR}/DEBIAN/prerm" <<'PRERM'
#!/usr/bin/env bash
set -e
systemctl stop linux-build-lab-sample.service 2>/dev/null || true
systemctl disable linux-build-lab-sample.service 2>/dev/null || true
exit 0
PRERM
chmod 0755 "${WORK_DIR}/DEBIAN/prerm"

cat > "${WORK_DIR}/DEBIAN/postrm" <<'POSTRM'
#!/usr/bin/env bash
set -e
systemctl daemon-reload || true
exit 0
POSTRM
chmod 0755 "${WORK_DIR}/DEBIAN/postrm"

PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"

dpkg-deb \
  --build \
  --root-owner-group \
  "${WORK_DIR}" \
  "${PACKAGE_PATH}"

echo "Created: ${PACKAGE_PATH}"
