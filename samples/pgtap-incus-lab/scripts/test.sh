#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PGDATABASE="${PGDATABASE:-pgtap_lab}"
PGHOST="${PGHOST:-/var/run/postgresql}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"

export PGHOST PGPORT PGUSER

if ! command -v pg_prove >/dev/null 2>&1; then
  echo "ERROR: pg_prove was not found." >&2
  echo "Install pgTAP / PostgreSQL TAP test tools first." >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql was not found." >&2
  exit 1
fi

if ! psql --dbname="${PGDATABASE}" --tuples-only --no-align \
  --command="SELECT 1 FROM pg_extension WHERE extname = 'pgtap';" \
  | grep -qx '1'; then
  echo "ERROR: pgTAP extension is not enabled in database: ${PGDATABASE}" >&2
  exit 1
fi

mapfile -t TEST_FILES < <(find "${REPO_ROOT}/tests" -maxdepth 1 -type f -name '*.sql' | sort)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No test files found under ${REPO_ROOT}/tests" >&2
  exit 1
fi

echo "Running pgTAP tests against database: ${PGDATABASE}"
pg_prove \
  --host="${PGHOST}" \
  --port="${PGPORT}" \
  --username="${PGUSER}" \
  --dbname="${PGDATABASE}" \
  "${TEST_FILES[@]}"
