#-------------------------------------------------------------
# H3C Magic NX30 Pro 112M (NMBM layout)
# 构建时追加到 target/linux/mediatek/image/filogic.mk 末尾
#
# 克隆自官方 Device/h3c_magic-nx30-pro-nmbm，与它的差异只有四项：
#   DEVICE_DTS      : mt7981b-h3c-magic-nx30-pro-nmbm → -112m
#   DEVICE_VARIANT  : (NMBM layout) → (112M NMBM layout)
#   IMAGE_SIZE      : 65536k → 114688k   (= ubi 分区大小 0x7000000)
#   SUPPORTED_DEVICES: 增加本变体与旧 nmbm 变体，允许 sysupgrade 升级
#
# 刻意保留的（与官方一致）：
#   DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
#     ↑ 开源 mt76 驱动。本方案不用 MTK 闭源 mt_wifi，两者会抢同一块射频，
#       绝不能同时出现。
#   KERNEL_IN_UBI := 1        内核打进 UBI 的 kernel 卷（现有 U-Boot 能直接读）
#   IMAGES += factory.bin     产出 append-ubi 的整包，可直接用 U-Boot web 刷
#   IMAGE/sysupgrade.bin      tar 包，也可从运行中的系统升级
#-------------------------------------------------------------
define Device/h3c_magic-nx30-pro-112m
  DEVICE_VENDOR := H3C
  DEVICE_MODEL := Magic NX30 Pro
  DEVICE_VARIANT := (112M NMBM layout)
  DEVICE_DTS := mt7981b-h3c-magic-nx30-pro-112m
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
  SUPPORTED_DEVICES := h3c,magic-nx30-pro-112m h3c,magic-nx30-pro-nmbm h3c,magic-nx30-pro
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 114688k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  KERNEL = kernel-bin | lzma | \
fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_INITRAMFS = kernel-bin | lzma | \
fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd
endef
TARGET_DEVICES += h3c_magic-nx30-pro-112m
