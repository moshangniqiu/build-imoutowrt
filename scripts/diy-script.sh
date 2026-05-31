#!/bin/bash
set -e -o pipefail

echo "=== diy-script: 开始自定义编译配置 ==="

# 修改默认IP
echo "[diy] 修改默认IP为 10.1.1.1"
sed -i 's/192.168.6.1/10.1.1.1/g' package/base-files/files/bin/config_generate
sed -i -E 's|^root:[^:]*:|root::|' package/base-files/files/etc/shadow

# 移除要替换的包（来自官方 feeds）
echo "[diy] 移除 feeds 中的旧版app"
rm -rf feeds/packages/net/mosdns feeds/packages/net/msd_lite feeds/packages/net/smartdns feeds/packages/net/dae feeds/packages/net/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,haproxy}
rm -rf feeds/luci/applications/luci-app-passwall

# 克隆第三方插件源（如果目录已存在则跳过，避免重复执行报错）
clone_if_missing() {
  local repo="$1" branch="$2" dest="$3"
  if [ -d "$dest" ]; then
    echo "[diy] 跳过已存在的仓库: $dest"
  else
    echo "[diy] 克隆: $repo -> $dest"
    git clone --depth=1 ${branch:+-b "$branch"} "$repo" "$dest"
  fi
}

clone_if_missing https://github.com/sbwml/luci-app-mosdns              "v5"     package/luci-app-mosdns
clone_if_missing https://github.com/sbwml/v2ray-geodata                 ""      package/v2ray-geodata
#clone_if_missing https://github.com/ximiTech/luci-app-msd_lite         ""     package/luci-app-msd_lite
#clone_if_missing https://github.com/ximiTech/msd_lite                  ""     package/msd_lite
#clone_if_missing https://github.com/pymumu/luci-app-smartdns           ""     package/luci-app-smartdns
#clone_if_missing https://github.com/pymumu/openwrt-smartdns            ""     package/smartdns
clone_if_missing https://github.com/QiuSimons/luci-app-daed            ""     package/luci-app-daed
#clone_if_missing https://github.com/Openwrt-Passwall/openwrt-passwall-packages "" package/passwall-packages
#clone_if_missing https://github.com/Openwrt-Passwall/openwrt-passwall  ""     package/passwall-luci
#clone_if_missing https://github.com/EasyTier/luci-app-easytier.git     ""     package/luci-app-easytier

# 强行修改 mediatek 平台固件自带的 rtl8261d 驱动源码
# 精准定位 target/linux/mediatek/ 下的所有 .c 和 .h 文件，不给任何漏网之鱼机会
find target/linux/mediatek/ -type f \( -name "*.c" -o -name "*.h" \) | while read -r file; do
    # 检查文件中是否包含需要修复的核心网卡接口函数，包含才修改
    if grep -q "rtl8261x_set_loopback" "$file"; then
        echo "[🚀 发现目标源码] 正在精准修复驱动文件: $file"
        # 1. 替换头文件及函数声明
        sed -i 's/int rtl8261x_set_loopback(struct phy_device \*phydev, bool enable);/int rtl8261x_set_loopback(struct phy_device \*phydev, bool enable, int loopback_mode);/g' "$file"
        # 2. 替换函数定义头
        sed -i 's/int rtl8261x_set_loopback(struct phy_device \*phydev, bool enable)/int rtl8261x_set_loopback(struct phy_device \*phydev, bool enable, int loopback_mode)/g' "$file"
        # 3. 强行插入 (void)loopback_mode; 规避未使用变量的警告
        sed -i '/int rtl8261x_set_loopback.*loopback_mode/,/{/ { /{/ a \\t(void)loopback_mode;' "$file"
    fi
done


# 修改版本为编译日期
DATE_VERSION="$(date +%Y.%m.%d)"
VERSION_FILE="include/version.mk"
echo "[diy] 修改版本为编译日期: $DATE_VERSION"
sed -i "s/^VERSION_NUMBER:=.*/VERSION_NUMBER:=-$DATE_VERSION by WoChen5770/" "$VERSION_FILE"

echo "=== diy-script: 完成 ==="
