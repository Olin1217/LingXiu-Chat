#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "请使用 sudo 运行备份脚本" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source /etc/lingxiu-api.env
set +a

if [[ -z "${DATABASE_URL:-}" || "${DATABASE_URL}" == "<POSTGRESQL_DATABASE_URL>" ]]; then
  echo "数据库尚未启用，本次没有需要备份的数据库" >&2
  exit 0
fi
if ! command -v pg_dump >/dev/null 2>&1; then
  echo "缺少 pg_dump，无法备份 PostgreSQL" >&2
  exit 1
fi

backup_dir=/var/backups/lingxiu/postgres
install -d -o root -g root -m 0700 "${backup_dir}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="${backup_dir}/lingxiu-${timestamp}.dump"
umask 077
pg_dump --format=custom --no-owner --no-acl --file="${backup_file}" "${DATABASE_URL}"
find "${backup_dir}" -type f -name 'lingxiu-*.dump' -mtime +7 -delete
echo "数据库备份完成：${backup_file}"
echo "注意：同机备份不能防止整块磁盘故障；购买 OSS 后应复制到异机存储"
