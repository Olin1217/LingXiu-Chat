#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "请使用 sudo 运行；脚本需要读取仅服务器可见的环境文件" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source /etc/lingxiu-api.env
set +a

response_file="$(mktemp)"
trap 'rm -f "${response_file}"' EXIT

status="$(curl --silent --show-error --output "${response_file}" --write-out '%{http_code}' \
  --connect-timeout 5 --max-time 115 \
  -H "X-LingXiu-Proxy-Token: ${LINGXIU_PROXY_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"input":[{"role":"user","content":[{"type":"input_text","text":"只回复 JSON：{\"status\":\"ok\"}"}]}],"store":false,"max_output_tokens":256}' \
  http://127.0.0.1:8080/v1/responses)"

provider_code="$(python3 - "${response_file}" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        body = json.load(handle)
except (OSError, UnicodeDecodeError, json.JSONDecodeError):
    print("unreadable_response")
else:
    print(body.get("error", {}).get("code", "none"))
PY
)"

echo "AI_HTTP_STATUS=${status}"
echo "AI_PROVIDER_CODE=${provider_code}"

if [[ "${status}" == "200" ]]; then
  exit 0
fi
if [[ "${status}" == "404" && "${provider_code}" == "ModelNotOpen" ]]; then
  echo "网络与鉴权已经连通，但模型尚未在方舟控制台开通" >&2
  exit 2
fi
exit 1
