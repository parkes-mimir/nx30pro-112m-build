#!/bin/bash
#
# 把 112M 大分区支持应用到 ImmortalWrt 24.10 源码树
#
# 用法: bash scripts/apply-112m.sh <源码目录>
#
# 做三件事：
#   1. 安装 112M 的 DTS
#   2. 在 filogic.mk 里注册 h3c_magic-nx30-pro-112m 设备
#   3. 给 board.d/02_network 的 MAC 读取加降级链
#      （112M 布局不再有 pdt_data_1，原逻辑会读不到 MAC 而随机生成）
#
set -euo pipefail

TOP="${1:-openwrt}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$TOP/target/linux/mediatek" ]; then
	echo "ERROR: '$TOP' 不是一个 ImmortalWrt 源码树" >&2
	exit 1
fi

# --- [1/3] DTS ---------------------------------------------------------
echo "==> [1/3] 安装 112M DTS"
install -m 0644 "$SRC/dts/mt7981b-h3c-magic-nx30-pro-112m.dts" \
	"$TOP/target/linux/mediatek/dts/mt7981b-h3c-magic-nx30-pro-112m.dts"

# --- [2/3] 设备定义 ----------------------------------------------------
echo "==> [2/3] 注册设备 h3c_magic-nx30-pro-112m"
FILOGIC_MK="$TOP/target/linux/mediatek/image/filogic.mk"
if grep -q 'Device/h3c_magic-nx30-pro-112m' "$FILOGIC_MK"; then
	echo "    已存在，跳过"
else
	printf '\n' >> "$FILOGIC_MK"
	cat "$SRC/device/h3c_magic-nx30-pro-112m.mk" >> "$FILOGIC_MK"
	echo "    已追加到 filogic.mk"
fi

# --- [3/3] MAC 降级链 --------------------------------------------------
echo "==> [3/3] 给 02_network 的 MAC 读取加降级链"
NET="$TOP/target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
if [ ! -f "$NET" ]; then
	echo "    WARNING: 未找到 $NET，跳过"
else
	python3 - "$NET" <<'PY'
import io, sys

path = sys.argv[1]
old = "wan_mac=$(mtd_get_mac_ascii pdt_data_1 ethaddr)"
new = ("wan_mac=$(mtd_get_mac_ascii pdt_data_1 ethaddr 2>/dev/null)\n"
       "\t\tif [ -z \"$wan_mac\" ]; then\n"
       "\t\t\twan_mac=$(mtd_get_mac_ascii Factory ethaddr 2>/dev/null)\n"
       "\t\tfi\n"
       "\t\tif [ -z \"$wan_mac\" ]; then\n"
       "\t\t\twan_mac=$(fw_printenv -n ethaddr 2>/dev/null)\n"
       "\t\tfi\n"
       "\t\tif [ -z \"$wan_mac\" ]; then\n"
       "\t\t\twan_mac=$(cat /sys/class/net/eth0/address)\n"
       "\t\tfi")

with io.open(path, "r", encoding="utf-8") as f:
    src = f.read()

if "mtd_get_mac_ascii Factory ethaddr" in src:
    print("    已打过补丁，跳过")
elif old not in src:
    print("    WARNING: 未找到 '%s'，02_network 结构可能已变化" % old)
    print("    请人工检查该文件里的 h3c,magic-nx30-pro 分支")
    sys.exit(0)
else:
    src = src.replace(old, new)
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print("    已打补丁: %s" % path)
PY
fi

echo "==> 完成"
