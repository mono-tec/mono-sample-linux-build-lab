#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${LAB_DIR}/config.env"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] config.env が見つかりません。"
  echo "[INFO] static IPでcreate-terraform-tfvars.shを実行するか、手動で作成してください。"
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=5432}"
: "${DB_USER:=postgres}"

DB_NAME="${1:-testdb}"
BACKUP_FILE="${2:-${LAB_DIR}/backup/base.dump}"

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "[ERROR] バックアップファイルが見つかりません: ${BACKUP_FILE}"
  exit 1
fi

echo "[INFO] Target: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";"

psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE \"${DB_NAME}\";"

pg_restore \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  --no-owner \
  --no-privileges \
  "${BACKUP_FILE}"

echo "[INFO] Restore completed."
