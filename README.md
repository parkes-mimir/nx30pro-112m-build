# H3C Magic NX30 Pro · 112M 大分区 · ImmortalWrt 24.10

用 GitHub Actions 云端编译 **官方 immortalwrt/openwrt-24.10 源码**的 112M 大分区固件。

**和社区现成方案的差别**：保留**开源 mt76 驱动**、**opkg 包管理**、**NMBM 坏块管理**，
只是把 ubi 从 64M 扩到 112M，并把 nikki(mihomo) + argon 主题编进去。

---

## 一、目录结构

```
.
├── .github/workflows/build.yml                    云端编译流水线
├── dts/mt7981b-h3c-magic-nx30-pro-112m.dts        112M 分区设备树（新增）
├── device/h3c_magic-nx30-pro-112m.mk              设备定义（追加到 filogic.mk）
├── configs/nx30pro-112m-immortalwrt-24.10.config  增量配置
└── scripts/apply-112m.sh                          三步注入脚本
```

`scripts/apply-112m.sh` 做三件事：

1. 安装 112M 的 DTS
2. 在 `target/linux/mediatek/image/filogic.mk` 末尾追加设备定义
3. 给 `base-files/etc/board.d/02_network` 的 MAC 读取打降级链补丁

---

## 二、分区布局

```
偏移        大小      名称          变动
0x0000000   1M        BL2          不变（只读）
0x0100000   0.5M      u-boot-env   不变
0x0180000   2M        Factory      不变（只读，无线校准）
0x0380000   2M        FIP          不变（只读，U-Boot）
0x0580000   112M      ubi          64M → 112M
  （原 pdt_data   6M / pdt_data_1 6M / exp 1M / plugin 37.5M 四个分区并入 ubi）

前 5.5MB 完全不动，128M 总量里剩 10.5MB 给 NMBM 坏块保留区。
```

**DTS 改动已验证**（本地 cpp + dtc 实测，编译后反解 dtb）：

```
label = "ubi"  reg = <0x580000 0x7000000>     ← 112M 生效
pdt_data / pdt_data_1 / exp / plugin           ← 四个节点全部消失
BL2 / u-boot-env / Factory / FIP               ← 四项原样保留
model = "H3C Magic NX30 Pro 112M (NMBM layout)"
```

---

## 三、怎么用

### 1. 推到自己的 GitHub 仓库

```bash
cd 本目录
git init
git add -A          # 注意包含 .github/
git commit -m "init: NX30 Pro 112M build (ImmortalWrt 24.10)"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

### 2. 触发编译

仓库 → **Actions** → 左侧 `Build ImmortalWrt 24.10 112M (NX30 Pro)` → **Run workflow**。

首次全新编译约 **2~3 小时**（含工具链）。之后有 ccache 缓存会快很多。

也可以打 tag 触发，会自动发 Release：

```bash
git tag v1.0 && git push origin v1.0
```

### 3. 取产物

- Actions 运行页的 **Artifacts**：`immortalwrt-h3c_magic-nx30-pro-112m`
- 或打了 tag 之后的 **Releases**

产物清单：

```
*112m-squashfs-factory.bin       ← U-Boot web failsafe 直接刷这个
*112m-squashfs-sysupgrade.bin    ← 从运行中的系统升级用
*112m-initramfs-kernel.bin       ← 内存启动验证用（不写 flash）
sha256sums
```

---

## 四、刷之前必须做的事

### 1. 确认 DTB 里的 ubi 是 112M

下载 `factory.bin` 后，先验分区表，**别信编译日志**：

```bash
# 从 factory.bin 里解出 FIT，取出 dtb
dumpimage -T flat_dt -l factory.bin
dumpimage -T flat_dt -p <fdt序号> -o /tmp/k.dtb factory.bin
dtc -I dtb -O dts /tmp/k.dtb | grep -A3 'label = "ubi"'
# 期望: reg = <0x580000 0x7000000>
```

如果看到 `0x4000000`（64M）→ **绝对不要刷**。

### 2. U-Boot 布局切到 immortalwrt-112m

Yuzhii 的多布局 FIP：断电重启进 web failsafe（`http://192.168.1.1`），
打开 `/mtd-layout`，选 `immortalwrt-112m`。

确认 `mtdparts` 变成：

```
nmbm0:1024k(bl2),512k(u-boot-env),2048k(Factory),2048k(fip),112M(ubi)
```

⚠️ 必须写死 `112M` 或 `114688k`，**不要用 `-(ubi)`**（`-` 表示到 flash 末尾约 122.5M，与 DTB 的 112M 不一致，UBI attach 会失败）。

### 3. 擦除 ubi 分区

NAND 特性：旧 UBI 元数据会干扰。在 U-Boot 的 Flash editor 里选 `ubi` → Erase。

### 4. 记录原以太网 MAC

112M 布局不再有 `pdt_data_1`，原厂把以太网 MAC 以 ASCII 文件 `ethaddr` 存在那里。
构建脚本已给 `02_network` 打了降级链（`pdt_data_1` → `Factory` → u-boot 环境变量），
但**刷之前先记下来**：

```sh
# 在当前系统上
mtd_get_mac_ascii pdt_data_1 ethaddr      # 可能已读不到
fw_printenv -n ethaddr                     # 从 U-Boot 环境读（本机为 70:2A:D7:B8:54:88）
```

### 5. 刷入

U-Boot web failsafe → **Firmware upgrade** → 上传 `*factory.bin` → 等 1~2 分钟。

---

## 五、内置什么

| 项 | 说明 |
|---|---|
| 驱动 | `kmod-mt7915e`（**开源 mt76**），WiFi6 双频 |
| 包管理 | `opkg` |
| 主题 | `luci-theme-argon` + 主题配置页 |
| 代理 | `luci-app-nikki`（mihomo 内核，**编进 rootfs**，不占 overlay） |
| 中文 | LuCI 基础/防火墙/软件包/argon/nikki 全中文 |
| 工具 | `luci-app-ttyd`、`luci-app-package-manager`、`htop`、`nano`、`uboot-envtools` |

编进 rootfs 而不事后 `opkg install` 的原因：mihomo 内核 30-50MB，
放 squashfs 里压缩存放且**不占 overlay**，112MB overlay 基本全留给你。

---

## 六、已验证 / 未验证

**已在本地验证**

- ✅ DTS 语法：cpp 预处理 + dtc 编译通过
- ✅ `&ubi { reg = ... }` 覆盖生效（编译后反解 dtb 确认 `0x580000 0x7000000`）
- ✅ `/delete-node/` 四个分区节点全部删除成功
- ✅ `model` 覆盖生效
- ✅ 重复 `/dts-v1/;`（include 链）不报错

**尚未验证（必须靠实际编译 + 上机）**

- ⬜ 云端完整编译能否通过（工具链、`check-size`、`IMAGE_SIZE` 与实际 rootfs 是否冲突）
- ⬜ `factory.bin` 的 UBI 卷结构（kernel/rootfs/rootfs_data）是否符合预期
- ⬜ 上机后 UBI attach 是否正常（`ubinfo` 应为 896 PEB）
- ⬜ MAC 降级链在实机上是否读到正确 MAC
- ⬜ nikki + mihomo 在开源 mt76 下的转发表现

---

## 七、出问题怎么办

| 现象 | 原因 | 处理 |
|---|---|---|
| 内核 panic `layout volume was not found` | U-Boot mtdparts 还是 64M | 进 failsafe 切布局，重刷 |
| 内核 panic `VFS: Unable to mount root` | DTB 与实际 UBI 不匹配 | 同上，确认 112M |
| 刷完没网、LAN/WAN 不分 | `02_network` 没匹配到 board_name | 检查 DTS 的 `compatible` 是否保持 `h3c,magic-nx30-pro-nmbm` |
| 内核 panic 后不自动重启 | 没有 `panic=N` 参数 | 物理断电重启，U-Boot 仍可用 |
| 彻底成砖（U-Boot 都起不来） | BL2/FIP 被写坏 | 串口 + [mtk_uartboot](https://github.com/981213/mtk_uartboot) 推 RAM 版 BL2 |

**112M 布局切换不碰 BL2 和 FIP**，所以最坏结果是「系统起不来但 U-Boot 完好」，
用 web failsafe 重刷 64M 固件即可恢复。BL2 至今仍是你设备的原厂原封（
sha256 `8d2af4b5c71af9df1264a1b63d6d98015576e99354d53e139f61e0c37ceb0bc7`）。

---

## 八、参考

- 官方源码：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) 分支 `openwrt-24.10`
- nikki：[nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki)
- U-Boot：[Yuzhii0718/bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd)
- 上游拒绝大分区的理由：[openwrt/openwrt PR #16668](https://github.com/openwrt/openwrt/pull/16668)

---

## 附：argon 壁纸汉化补丁（开箱即用）

本仓库的 `files/` 目录包含两个覆盖文件，编译时会由 `apply-112m.sh` 第 4 步
复制进 ImmortalWrt 源码树的 `files/`，在 rootfs 组装阶段覆盖 argon 包自带文件：

- `files/usr/libexec/rpcd/luci.argon_wallpaper` — 增加 `custom` 壁纸源，从
  `argon.@global[0].wallpaper_url` 读取任意图片 URL。
- `files/www/luci-static/resources/view/argon-config.js` — Argon 配置页增加
  「自定义网址」选项与输入框（已汉化）。

同时写入 uci-default（`99_zzz_nx30pro_argon`），让新固件首次启动即：

```
online_wallpaper = custom
wallpaper_url    = https://api.yppp.net/pc    ← 随机二次元横图
```

刷机后用户可在 LuCI「系统 → Argon 主题设置 → 壁纸来源」里改成任何返回图片的 URL，
例如必应、unsplash、自己的图床等，无需重新编译。

**原理**：OpenWrt 编译系统会递归复制源码树根目录 `files/` 到 rootfs，
在软件包安装之后覆盖同名文件，因此这是让"别人刷固件就自带"的标准做法。
