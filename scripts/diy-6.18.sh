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

# 应用补丁
if [ -d "$GITHUB_WORKSPACE/patches/6.18" ]; then
  echo "[diy] 应用自定义补丁..."
  find "$GITHUB_WORKSPACE/patches/6.18" -type f -name "*.patch" | sort | while read patch_file; do
    echo "[diy] 应用补丁: $patch_file"
    patch -p1 < "$patch_file" || echo "[diy] 警告：应用补丁失败，继续..."
  done
else
  echo "[diy] patches/6.18 目录不存在，跳过"
fi
