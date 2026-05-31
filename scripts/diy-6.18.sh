#!/bin/bash
set -e -o pipefail

# 修补 filogic 6.18 内核配置，启用 BPF 相关选项
KCFG="target/linux/mediatek/filogic/config-6.18"
if [ -f "$KCFG" ]; then
  echo "[diy] 补丁内核配置: $KCFG (启用 BPF)"
  for opt in CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_NET_SCH_BPF; do
    sed -i "/^${opt}=.*/d" "$KCFG"
    sed -i "/^# ${opt} is not set/d" "$KCFG"
  done
  cat >> "$KCFG" <<'EOF'
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_NET_SCH_BPF=y
EOF
else
  echo "[diy] 内核配置未找到: $KCFG"
fi

# 同步仓库内维护的 patches 目录到 OpenWrt 源码树

if [ -d "$GITHUB_WORKSPACE/patches/6.18" ]; then
  echo "[diy] 同步自定义 patches/6.18 目录到源码树"
  cp -rf "$GITHUB_WORKSPACE/patches/6.18/." ./
else
  echo "[diy] patches/6.18 目录不存在，跳过"
fi

# ==================== 修复 RTL8261D 驱动在 Linux 6.18+ 下的编译错误 ====================
echo "[diy] 开始注入 RTL8261D 驱动修复补丁"

# 在 package 目录或 feeds 中全局寻找 rtl8261d 包的实际路径
TARGET_DIR=$(find . -type d -path "*/kernel/rtl8261d" -print -quit || true)

if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR/patches"
    cat << 'EOF' > "$TARGET_DIR/patches/999-fix-linux-6.18-compatibility.patch"
--- a/src/rtl8261d_main.c
+++ b/src/rtl8261d_main.c
@@ -942,7 +942,7 @@
 #endif
 
-int rtl8261d_set_led_blink_mode(struct phy_device *phydev, uint16_t mode, uint16_t led_id)
+static int rtl8261d_set_led_blink_mode(struct phy_device *phydev, uint16_t mode, uint16_t led_id)
 {
 	return 0;
 }
@@ -1187,7 +1187,7 @@
 	return 0;
 }
 
-int rtl8261x_config_intr(struct phy_device *phydev)
+static int rtl8261x_config_intr(struct phy_device *phydev)
 {
 	int err;
 	uint16_t val = 0;
@@ -1228,7 +1228,7 @@
 	return err;
 }
 
-int rtl8261x_match_phy_device_c45(struct phy_device *phydev,
+static int rtl8261x_match_phy_device_c45(struct phy_device *phydev,
 				  const struct phy_device_id *pid)
 {
 	uint32_t phy_id = pid->phy_id;
@@ -1252,7 +1252,7 @@
 	return ((phydev->c45_ids.device_ids[MDIO_MMD_VEND2] & pid->phy_id_mask) == (phy_id & pid->phy_id_mask));
 }
 
-int rtl8261x_probe(struct phy_device *phydev)
+static int rtl8261x_probe(struct phy_device *phydev)
 {
 	int err;
 	uint16_t val;
@@ -1400,9 +1400,10 @@
-int rtl8261x_set_loopback(struct phy_device *phydev, bool enable)
+int rtl8261x_set_loopback(struct phy_device *phydev, bool enable, int mode)
 {
 	int err;
 	uint16_t val = 0;
+	(void)mode;
 
 	if (enable) {
 		val = BMCR_LOOPBACK;
EOF
    echo "[diy] RTL8261D 驱动补丁已成功写入到: $TARGET_DIR/patches/"
else
    echo "[diy] 警告: 未在源码中找到 RTL8261D 驱动目录，跳过补丁注入"
fi
# ===================================================================================
