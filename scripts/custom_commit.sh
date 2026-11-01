#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# config/config 自定义提交读取器
#
# 用法:
#   custom_commit.sh enabled      # custom=true 时退出码 0，否则 1
#   custom_commit.sh get <key>    # 打印 <key> 锁定的 commit hash（未锁定则输出为空）
#
# <key> 为 SUSFS 分支名（如 oki-android16-6.12）
# 配置文件说明见仓库根目录 config/config
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CUSTOM_COMMIT_CONFIG:-$REPO_ROOT/config/config}"

# 读取配置项：精确匹配键名，忽略注释与空白（兼容 Windows 编辑产生的 CRLF）
read_value() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || return 0
  awk -v k="$key" '
    {
      sub(/[[:space:]]*#.*/, "")
      n = index($0, "=")
      if (n > 1 && substr($0, 1, n - 1) == k) {
        v = substr($0, n + 1)
        gsub(/[[:space:]\r]/, "", v)
        out = v
      }
    }
    END { printf "%s", out }
  ' "$CONFIG_FILE"
}

case "${1:-}" in
  enabled)
    [ "$(read_value custom)" = "true" ]
    ;;
  get)
    key="${2:-}"
    if [ -z "$key" ]; then
      echo "usage: $0 get <key>" >&2
      exit 1
    fi
    value="$(read_value "$key")"
    [ -n "$value" ] || exit 0
    value="${value,,}"
    if [[ ! "$value" =~ ^[0-9a-f]{40}$ ]]; then
      echo "::error::config/config: '$key' 的值不是合法的 40 位 commit hash: $value" >&2
      exit 1
    fi
    printf '%s\n' "$value"
    ;;
  *)
    echo "usage: $0 {enabled|get <key>}" >&2
    exit 1
    ;;
esac
