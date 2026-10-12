#!/usr/bin/env bash
set -euo pipefail

public_base_url="${1:-}"
ca_file="${2:-}"

if [[ -z "${public_base_url}" ]]; then
  echo "用法：$0 https://服务器或域名 [CA证书路径]" >&2
  exit 1
fi

curl_options=(--silent --show-error --connect-timeout 5 --max-time 15)
if [[ -n "${ca_file}" ]]; then
  curl_options+=(--cacert "${ca_file}")
fi

health_json="$(curl --fail "${curl_options[@]}" "${public_base_url}/health")"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["status"] == "ok"; assert value["api_version"] == "v1"' <<<"${health_json}"

unauthorized_status="$(curl "${curl_options[@]}" --output /dev/null --write-out '%{http_code}' \
  -H 'Content-Type: application/json' \
  --data '{"input":[]}' \
  "${public_base_url}/v1/responses" || true)"

if [[ "${unauthorized_status}" != "401" ]]; then
  echo "未授权保护检查失败，收到 HTTP ${unauthorized_status}" >&2
  exit 1
fi

echo "公网健康检查、HTTPS 校验和未授权保护均通过"
