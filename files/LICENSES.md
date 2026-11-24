# files/ 目录第三方文件许可说明

本仓库主体遵循 ImmortalWrt 主线的 **GPL-2.0-only**（见仓库根目录 `LICENSE`）。

`files/` 下下列文件派生自 **luci-theme-argon** 项目（原作者 Jerrykuku，
Copyright 2020-2025），其原始许可为 **Apache-2.0**：

| 文件 | 上游来源 | 原许可 | 本仓库改动 |
|---|---|---|---|
| `www/luci-static/resources/view/argon-config.js` | jerrykuku/luci-theme-argon | Apache-2.0 | 增加 Custom URL 选项及汉化 |
| `www/luci-static/argon/css/cascade.css` | jerrykuku/luci-theme-argon | Apache-2.0 | 增加移动端竖图切换规则 |
| `usr/share/ucode/luci/template/themes/argon/*.ut` | jerrykuku/luci-theme-argon | Apache-2.0 | 修改 CSS 版本戳、渲染双背景层 |
| `usr/libexec/rpcd/luci.argon_wallpaper` | jerrykuku/luci-theme-argon（原作者 jjm2473）| Apache-2.0 | 增加 custom 壁纸源（读 UCI）|

这些文件保留其原始版权声明，按其原 Apache-2.0 许可继续提供；本仓库对其所做的
修改同样以 Apache-2.0 提供。其余脚本（DTS、设备定义、apply 脚本、sync 工具、
README 等）为本项目原创，遵循根目录的 GPL-2.0-only。

Apache-2.0 全文：https://www.apache.org/licenses/LICENSE-2.0
上游项目：https://github.com/jerrykuku/luci-theme-argon
