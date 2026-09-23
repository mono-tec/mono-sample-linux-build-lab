#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_FILE="${BACKUP_FILE:-${REPO_ROOT}/backup/base.dump}"
PGDATABASE="${PGDATABASE:-pgtap_lab}"
PGHOST="${PGHOST:-/var/run/postgresql}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"

export PGHOST PGPORT PGUSER

case "${PGDATABASE}" in
  postgres|template0|template1)
    echo "ERROR: Refusing to recreate protected database: ${PGDATABASE}" >&2
    exit 1
    ;;
esac

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "ERROR: Backup file not found: ${BACKUP_FILE}" >&2
  echo "Place a pg_dump -Fc backup at backup/base.dump or set BACKUP_FILE." >&2
  exit 1
fi

if [[ ! -s "${BACKUP_FILE}" ]]; then
  echo "ERROR: Backup file is empty: ${BACKUP_FILE}" >&2
  exit 1
fi

for cmd in dropdb createdb pg_restore psql; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}" >&2
    exit 1
  fi
done

echo "[1/6] Recreating database: ${PGDATABASE}"
dropdb --if-exists "${PGDATABASE}"
createdb "${PGDATABASE}"

echo "[2/6] Restoring backup: ${BACKUP_FILE}"
pg_restore \
  --exit-on-error \
  --no-owner \
  --no-privileges \
  --dbname="${PGDATABASE}" \
  "${BACKUP_FILE}"

echo "[3/6] Enabling pgTAP"
psql --dbname="${PGDATABASE}" --set=ON_ERROR_STOP=1 \
  --command='CREATE EXTENSION IF NOT EXISTS pgtap;'

echo "[4/6] Loading fixtures/settings.sql"
psql --dbname="${PGDATABASE}" --file="${REPO_ROOT}/fixtures/settings.sql"

echo "[5/6] Loading fixtures/test-data.sql"
psql --dbname="${PGDATABASE}" --file="${REPO_ROOT}/fixtures/test-data.sql"

echo "[6/6] Restore completed"
echo "Database: ${PGDATABASE}"
