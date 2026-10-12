#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "请使用 sudo 运行部署脚本" >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$(cd -- "${script_dir}/.." && pwd)"

if [[ ! -f /etc/lingxiu-api.env ]]; then
  echo "缺少 /etc/lingxiu-api.env；部署脚本不会自动生成或输出密钥" >&2
  exit 1
fi

install -d -o root -g root -m 0755 /opt/lingxiu-api
install -o root -g root -m 0755 "${source_dir}/lingxiu_proxy.py" /opt/lingxiu-api/lingxiu_proxy.py
install -o root -g root -m 0644 "${source_dir}/lingxiu-api.service" /etc/systemd/system/lingxiu-api.service

python3 -m py_compile /opt/lingxiu-api/lingxiu_proxy.py
systemctl daemon-reload
systemctl enable --now lingxiu-api.service
systemctl restart lingxiu-api.service

if [[ -d /etc/nginx/sites-available && -f "${source_dir}/nginx-lingxiu.conf" ]]; then
  install -o root -g root -m 0644 "${source_dir}/nginx-lingxiu.conf" /etc/nginx/sites-available/lingxiu-api
  ln -sfn /etc/nginx/sites-available/lingxiu-api /etc/nginx/sites-enabled/lingxiu-api
  # Ubuntu enables a public port-80 sample site by default. LingXiu's IP
  # development deployment does not need it, and leaving it enabled exposes
  # an unrelated static document root. Keep the source config recoverable in
  # sites-available while removing only its enablement symlink.
  if [[ -L /etc/nginx/sites-enabled/default ]]; then
    unlink /etc/nginx/sites-enabled/default
  fi
  nginx -t
  systemctl reload nginx
fi

healthy=false
for _ in {1..20}; do
  if curl --fail --silent --show-error http://127.0.0.1:8080/health >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 0.5
done
if [[ "${healthy}" != "true" ]]; then
  systemctl status lingxiu-api.service --no-pager -l >&2 || true
  exit 1
fi
echo "灵嗅后端部署完成，内部健康检查通过"
