#!/usr/bin/env bash
set -euo pipefail

simulator_id="${1:-booted}"
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_directory="$(cd "${script_directory}/.." && pwd)"
development_ca="${project_directory}/LingXiu/Resources/LingXiuDevelopmentCA.pem"

if [[ ! -f "${development_ca}" ]]; then
  echo "找不到灵嗅开发 CA：${development_ca}" >&2
  exit 1
fi

if ! xcrun --find simctl >/dev/null 2>&1; then
  echo "当前终端未指向完整 Xcode，请先设置 DEVELOPER_DIR 后重试。" >&2
  exit 1
fi

if [[ "${simulator_id}" != "booted" ]]; then
  xcrun simctl boot "${simulator_id}" 2>/dev/null || true
fi

xcrun simctl bootstatus "${simulator_id}" -b
xcrun simctl keychain "${simulator_id}" add-root-cert "${development_ca}"

echo "灵嗅开发 CA 已加入模拟器信任库：${simulator_id}"
echo "此配置仅用于无正式域名阶段的本地联调。"
