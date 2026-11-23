#!/bin/sh
# NX30 Pro 配置热更新客户端
# 从 GitHub raw 拉 manifest，逐项校验 sha256 后覆盖本地文件。
# 设计原则：任何单项失败都只跳过该项，绝不影响系统启动或已有功能。
# 用法: /usr/bin/nx30-sync [manifest-url]

set -u

BASE="${1:-https://raw.githubusercontent.com/parkes-mimir/nx30pro-112m-build/main/sync/manifest}"
RAW_ROOT="https://raw.githubusercontent.com/parkes-mimir/nx30pro-112m-build/main"
BACKUP_DIR="/etc/nx30-sync/backup"
TMP="$(mktemp -d /tmp/nx30-sync.XXXXXX)" || exit 1
LOG_TAG="nx30-sync"

log() { logger -t "$LOG_TAG" "$*"; echo "$*"; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

mkdir -p "$BACKUP_DIR"

# 拉 manifest（3 次重试，每次 8s 超时）
MF="$TMP/manifest"
ok=0
for i in 1 2 3; do
    if curl -fsSL --max-time 8 "$BASE" -o "$MF" 2>/dev/null && [ -s "$MF" ]; then
        ok=1; break
    fi
    sleep 2
done
if [ "$ok" -ne 1 ]; then
    log "manifest 拉取失败，跳过本次同步"
    exit 0
fi

changed=0
while read -r sha target rel; do
    case "$sha" in ''|\#*) continue;; esac
    [ -z "$target" ] && continue

    src="${RAW_ROOT}/${rel}"
    dl="$TMP/payload"
    rm -f "$dl"

    if ! curl -fsSL --max-time 15 "$src" -o "$dl" 2>/dev/null; then
        log "跳过 $target（下载失败）"
        continue
    fi
    actual="$(sha256sum "$dl" 2>/dev/null | awk '{print $1}')"
    if [ "$actual" != "$sha" ]; then
        log "跳过 $target（sha256 不符: 期望 ${sha:0:12} 实际 ${actual:-none}）"
        continue
    fi
    # 内容一致就不动，避免无谓写入
    if [ -f "$target" ] && [ "$(sha256sum "$target" | awk '{print $1}')" = "$sha" ]; then
        continue
    fi
    # 覆盖前备份原文件
    if [ -f "$target" ]; then
        cp -p "$target" "$BACKUP_DIR/$(basename "$target").bak" 2>/dev/null
    fi
    # busybox 无 install 命令，用 cat 重定向 + chmod 代替
    if cat "$dl" > "$target" 2>/dev/null; then
        chmod 0644 "$target" 2>/dev/null
        changed=$((changed+1))
        log "已更新 $target"
    else
        log "写入失败 $target"
    fi
done < "$MF"

# 壁纸脚本需要可执行权限（manifest 无法表达权限，这里按路径特判）
[ -f /usr/libexec/rpcd/luci.argon_wallpaper ] && chmod 0755 /usr/libexec/rpcd/luci.argon_wallpaper

log "同步完成，更新 $changed 个文件"
exit 0
