#!/usr/bin/env bash
set -euo pipefail

backup_file="${1:-}"
confirmation="${2:-}"

if [[ ${EUID} -ne 0 ]]; then
  echo "请使用 sudo 运行恢复脚本" >&2
  exit 1
fi
if [[ -z "${backup_file}" || ! -f "${backup_file}" ]]; then
  echo "请提供一个存在的 .dump 备份文件" >&2
  exit 1
fi
if [[ "${confirmation}" != "--confirm-database-replace" ]]; then
  echo "恢复会覆盖目标数据库；确认后附加 --confirm-database-replace" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source /etc/lingxiu-api.env
set +a

if [[ -z "${DATABASE_URL:-}" || "${DATABASE_URL}" == "<POSTGRESQL_DATABASE_URL>" ]]; then
  echo "DATABASE_URL 尚未配置" >&2
  exit 1
fi

pg_restore --clean --if-exists --no-owner --no-acl --dbname="${DATABASE_URL}" "${backup_file}"
echo "数据库恢复完成"
