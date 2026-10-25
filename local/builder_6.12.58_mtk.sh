#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 设置自定义参数 =====
echo "===== 欧加真MT6993通用6.12.58 A16 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android16-5-ge7f2a9832757-ab13799791-4k）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android16-5-ge7f2a9832757-ab13799791-4k}
read -p "是否启用susfs？(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：n): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-n}
read -p "KSU分支版本(r=BakaSU, y=SukiSU Ultra, f=FinaSU, n=KernelSU Next, k=KSU, l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：y): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-y}
read -p "是否添加 BBR 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否添加 Droidspaces 容器支持？(n禁用/s标准/e扩展，默认：n): " APPLY_DROIDSPACES
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
read -p "是否启用ADIOS调度器？(y/n，默认：y): " APPLY_ADIOS
APPLY_ADIOS=${APPLY_ADIOS:-y}
read -p "是否启用Re-Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="BakaSU"
elif [[ "$KSU_BRANCH" == "f" || "$KSU_BRANCH" == "F" ]]; then
  KSU_TYPE="FinaSU"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "启用susfs: $APPLY_SUSFS"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "应用 BBR 等算法: $APPLY_BBR"
echo "应用 Droidspaces 容器支持: $APPLY_DROIDSPACES"
echo "启用ADIOS调度器: $APPLY_ADIOS"
echo "启用Re-Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."
# Function to run a command with sudo if not already root
SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev libdw-dev cpio xz-utils tar unzip aria2

# ===== 初始化仓库 =====
echo ">>> 初始化仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace

echo "正在克隆源码仓库..."
aria2c -s16 -x16 -k1M ttps://github.com/cctv18/android_kernel_oneplus_mt6993/archive/refs/heads/oneplus/mt6993_b_16.0_ace_6_ultra.zip -o common.zip && 
unzip -q common.zip && 
mv "android_kernel_oneplus_mt6993-oneplus-mt6993_b_16.0_ace_6_ultra" common &&
rm -rf common.zip &

echo "正在克隆llvm-clang19工具链..." &&
mkdir -p clang19 &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/clang-r536225.zip -o clang.zip &&
unzip -q clang.zip -d clang19 &&
rm -rf clang.zip &

echo "正在克隆Rust 1.82.0工具链..." &&
mkdir -p rust &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/rust.zip -o rust.zip &&
unzip -q rust.zip -d rust &&
rm -rf rust.zip &

echo "正在克隆构建工具..." &&
aria2c -s16 -x16 -k1M https://github.com/cctv18/oneplus_sm8650_toolchain/releases/download/LLVM-Clang19-r536225/build-tools.zip -o build-tools.zip &&
unzip -q build-tools.zip &&
rm -rf build-tools.zip &

wait
echo "所有源码及llvm-clang19工具链初始化完成！"
echo ">>> 初始化仓库完成!"

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done
sudo sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-'${CUSTOM_SUFFIX}'"/' ./common/arch/arm64/configs/gki_defconfig
sed -i 's/${scm_version}//' ./common/scripts/setlocalversion
echo "CONFIG_LOCALVERSION_AUTO=n" >> ./common/arch/arm64/configs/gki_defconfig

# ===== 拉取 KSU 并设置版本号 =====
if [[ $KSU_BRANCH == [yYrR] ]]; then
  echo ">>> 拉取 BakaSU 并设置版本（由于SukiSU长期未维护无法正常编译，且BakaSU兼容sukisu管理器，故SukiSU源码仓库已重定向为bakasu）..."
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash -s main
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd KernelSU-Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" kernel/Kbuild
  #为KernelSU Next添加WildKSU管理器支持
  cd ../common/drivers/kernelsu
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/apk_sign.patch
  patch -p2 -N -F 3 < apk_sign.patch || true
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo "正在配置原版 KernelSU (tiann/KernelSU)..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
elif [[ "$KSU_BRANCH" == [fF] ]]; then
  echo ">>> 拉取 FinaSU 并检出到官方最新 Release 标签提交（KSU 版本 = 30000 + 提交数，与官方管理器 versionCode 一致）..."
  git clone https://github.com/LyraVoid/FinaSU.git KernelSU
  # FinaSU 自带的 kernel/setup.sh 会克隆上游 tiann/KernelSU，不可用；此处手动完成 in-tree 集成
  REL_JSON=$(curl -s --fail --max-time 30 "https://api.github.com/repos/LyraVoid/FinaSU/releases/latest" || true)
  REL_TAG=$(printf '%s' "$REL_JSON" | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1 || true)
  REL_APK_URL=$(printf '%s' "$REL_JSON" | grep -oP '"browser_download_url":\s*"\K[^"]+\.apk' | head -n1 || true)
  CERT_TOOL="$SCRIPT_DIR/../scripts/finasu_compat/extract_manager_cert.py"
  if [ ! -f "$CERT_TOOL" ]; then
    wget -q "https://github.com/LingLuo17/oppo_oplus_realme_sm8850/raw/refs/heads/main/scripts/finasu_compat/extract_manager_cert.py" -O "$CERT_TOOL" || CERT_TOOL=""
  fi
  if [ -n "$REL_TAG" ] && [ -n "$REL_APK_URL" ]; then
    git -C KernelSU fetch origin --tags 2>/dev/null || true
    if git -C KernelSU checkout --detach "$REL_TAG" 2>/dev/null; then
      echo ">>> FinaSU 已检出到官方 Release $REL_TAG 对应提交"
      REL_APK="FinaSU-manager.apk"
      if curl -sL --fail --retry 3 --max-time 300 -o "$REL_APK" "$REL_APK_URL" && [ -n "$CERT_TOOL" ] && [ -f "$CERT_TOOL" ]; then
        CERT_INFO=$(python3 "$CERT_TOOL" "$REL_APK" | head -n1 || true)
        CERT_SIZE=$(printf '%s' "$CERT_INFO" | awk '{print $1}')
        CERT_HASH=$(printf '%s' "$CERT_INFO" | awk '{print $2}')
      fi
    else
      echo ">>> 警告：FinaSU 检出 Release $REL_TAG 失败，内核跟随 master HEAD"
    fi
  else
    echo ">>> 警告：未获取到 FinaSU 官方最新 Release 信息，内核跟随 master HEAD"
  fi
  KSU_VERSION=$(expr $(git -C KernelSU rev-list --count HEAD) + 30000 2>/dev/null || echo 114514)
  echo ">>> FinaSU KSU 版本：$KSU_VERSION"
  if [ -n "$CERT_SIZE" ] && [ -n "$CERT_HASH" ]; then
    echo ">>> 注入 FinaSU 管理器签名证书到内核第二信任槽: size=$CERT_SIZE sha256=$CERT_HASH"
    awk -v size="$CERT_SIZE" -v hash="$CERT_HASH" '
      !done && /^ccflags-y \+= -DEXPECTED_HASH=/ {
        print
        print "KSU_EXPECTED_SIZE2 := " size
        print "KSU_EXPECTED_HASH2 := " hash
        print "KSU_SECOND_SIGNATURE_RELEASE := 1"
        done = 1
        next
      }
      { print }
    ' KernelSU/kernel/Kbuild > KernelSU/kernel/Kbuild.new && mv KernelSU/kernel/Kbuild.new KernelSU/kernel/Kbuild
  else
    echo ">>> 警告：未取得 FinaSU 管理器签名证书，FinaSU 管理器可能显示未安装"
  fi
  # 本地检出同样是 detached 提交，Kbuild 的 rev-parse --abbrev-ref 会显示 @HEAD，固定为品牌名
  sed -i 's/@[$](KSU_VERSION_BRANCH)/@cctv18/' KernelSU/kernel/Kbuild
  grep -q '@cctv18' KernelSU/kernel/Kbuild || echo ">>> 警告：FinaSU 品牌名替换未命中（上游 Kbuild 结构可能已变化）"
  DRIVER_DIR=./common/drivers
  ln -sfn "$(pwd)/KernelSU/kernel" "$DRIVER_DIR/kernelsu"
  # 实体化树内 uapi 符号链接（其指向仓库根 uapi/），规避跨目录符号链接解析差异
  rm -f KernelSU/kernel/include/uapi
  cp -r KernelSU/uapi KernelSU/kernel/include/uapi
  # 供编译阶段以 KCFLAGS 注入头文件搜索目录
  KSU_INC_DIR="$(pwd)/KernelSU/kernel"
  export KSU_INC_DIR
  grep -q "obj-.*CONFIG_KSU.*kernelsu/" "$DRIVER_DIR/Makefile" || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> "$DRIVER_DIR/Makefile"
  grep -q 'drivers/kernelsu/Kconfig' "$DRIVER_DIR/Kconfig" || \
    sed -i "/endmenu/i source \"drivers/kernelsu/Kconfig\"" "$DRIVER_DIR/Kconfig"
else
  echo "已选择无内置KernelSU模式，跳过配置..."
fi

# ===== 克隆补丁仓库&应用 SUSFS 补丁 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 应用 SUSFS&hook 补丁..."
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 克隆补丁仓库..."
  git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu -b oki-android16-6.12
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android16-6.12.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  patch -p1 -F 3 < 50_add_susfs_in_gki-android16-6.12.patch || true
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd "$WORKDIR/kernel_workspace"
if [[ "$KSU_BRANCH" == [kK] && "$APPLY_SUSFS" == [yY] ]]; then
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cd ./KernelSU
  patch -p1 -F 3 < 10_enable_susfs_for_ksu.patch || true
fi
cd "$WORKDIR/kernel_workspace"

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8850.git
  cp ./oppo_oplus_realme_sm8850/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8850/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < 001-lz4.patch || true
  patch -p1 -F 3 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace/common"
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/lz4kd.patch
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

# 写入通用 SUSFS/KSU 配置
echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  if [[ "$KSU_BRANCH" == [fF] ]]; then
    echo ">>> FinaSU：写入 FinaSU Kconfig 定义的 SUSFS 配置项（try-umount/自动隐藏等由其树内扩展原生处理，无对应独立开关）..."
    echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
  else
  echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
  fi
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
#添加对 Mountify (backslashxx/mountify) 模块的支持
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"

# 开启O2编译优化配置
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
#跳过将uapi标准头安装到 usr/include 目录的不必要操作，节省编译时间
echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"

# 应用 CVE_2026_43499 修复补丁
cd common
wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/cve-2026-43499-rtmutex-6.12.patch
patch -p1 -F 3 < cve-2026-43499-rtmutex-6.12.patch
cd ..

# 6.12内核Rust配置
echo "CONFIG_RUST=y" >> ./common/arch/arm64/configs/gki_defconfig
echo "CONFIG_ANDROID_BINDER_IPC_RUST=m" >> ./common/arch/arm64/configs/gki_defconfig

# 仅在启用了 LZ4KD 补丁时添加相关算法支持
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
CONFIG_ZRAM_BACKEND_LZ4HC=y
CONFIG_ZRAM_BACKEND_LZ4K=y
CONFIG_ZRAM_BACKEND_LZ4KD=y
CONFIG_ZRAM_BACKEND_842=y
EOF

fi

# ===== 启用网络功能增强优化配置 =====
if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  #由于部分机型的vintf兼容性检测规则，在开启CONFIG_IP6_NF_NAT后开机会出现"您的设备内部出现了问题。请联系您的设备制造商了解详情。"的提示，故添加一个配置修复补丁，在编译内核时隐藏CONFIG_IP6_NF_NAT=y但不影响对应功能编译
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

# ===== 添加 BBR 等一系列拥塞控制算法 =====
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

# ===== 启用 Droidspaces 容器支持 =====
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  echo ">>> 正在添加 Droidspaces 容器支持..."
  # 开启 Droidspaces 容器所需内核支持
  echo "CONFIG_PID_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPC_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_USER_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SYSVIPC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_DEVTMPFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NAMESPACES=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_POSIX_MQUEUE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "$DEFCONFIG_FILE"
  # 开启 NTSync
  echo "CONFIG_NTSYNC=y" >> "$DEFCONFIG_FILE"
  cd common
  # 应用 Droidspaces 容器必须补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_sysvipc_kabi_a16-6.12.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_a16-6.12.patch || true
  # 修补 oplus_bsp_midas 行为，避免开机崩溃
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  # 应用 NTSync 补丁
  wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/ntsync_compat_android16-6.12.patch
  patch -p1 -F 3 < ntsync_compat_android16-6.12.patch || true
  cd ..
  if [[ "$APPLY_DROIDSPACES" == [eE] ]]; then
    echo "正在启用容器环境扩展支持..."
    # 开启虚拟 HCI 设备支持
    echo "CONFIG_BT_HCIVHCI=y" >> "$DEFCONFIG_FILE"
    # 开启 systemd-coredump 支持
    echo "CONFIG_STATIC_USERMODEHELPER=n" >> "$DEFCONFIG_FILE"
    # 添加 Lindroid EVDI DRM 驱动
    # echo "CONFIG_DRM_LINDROID_EVDI=y" >> "$DEFCONFIG_FILE"
    # cd common
    # wget https://github.com/cctv18/oppo_oplus_realme_sm8850/raw/refs/heads/main/droidspaces_patch/evdi_drm.patch
    # patch -p1 -F 3 < evdi_drm.patch || true
    # cd ..
  fi
fi

# ===== 启用ADIOS调度器 =====
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  echo ">>> 正在启用ADIOS调度器..."
  echo "CONFIG_MQ_IOSCHED_ADIOS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用Re-Kernel =====
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re-Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_REKERNEL_NETWORK=y" >> "$DEFCONFIG_FILE"
fi

# ===== 启用内核级基带保护 =====
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common
  curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

# ===== 禁用 defconfig 检查 =====
echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

# ===== 编译内核 =====
echo ">>> 开始编译内核..."
WORKDIR="$(pwd)"
export PATH="$WORKDIR/clang19/bin:$PATH"
export PATH="$WORKDIR/build-tools/bin:$PATH"
export PATH="$WORKDIR/rust/bin:$PATH"
CLANG_DIR="$WORKDIR/clang19/bin"
CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1)"
RUSTC_VERSION="$(rustc -V 2>/dev/null | head -n1)"
BINDGEN_VERSION="$(bindgen --version 2>/dev/null | head -n1)"
export CC="$CLANG_DIR/clang"
export HOSTCC="$CLANG_DIR/clang"
export RUSTC="rustc"
export BINDGEN="bindgen"
export LIBCLANG_PATH="$WORKDIR/clang19/lib"
export LLVM=1 LLVM_IAS=1
export ARCH=arm64 SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LD=ld.lld HOSTLD=ld.lld AR=llvm-ar NM=llvm-nm AS=clang READELF=llvm-readelf
export OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump OBJSIZE=llvm-size STRIP=llvm-strip
KCFLAGS+=" -no-canonical-prefixes"
KCFLAGS+=" -O2"
KCFLAGS+=" -pipe"
KCFLAGS+=" -Wno-error"
KCFLAGS+=" -fno-stack-protector"
KCFLAGS+=" -D__ANDROID_COMMON_KERNEL__"
export KCFLAGS
echo "编译器信息:"
echo "Clang版本: $CLANG_VERSION"
echo "LLD版本: $LLD_VERSION"
echo "Rustc版本: $RUSTC_VERSION"
echo "Bindgen版本: $BINDGEN_VERSION"
pahole_version=$(pahole --version 2>/dev/null | head -n1); [ -z "$pahole_version" ] && echo "pahole版本：未安装" || echo "pahole版本：$pahole_version"

cd common

COMMON_REAL_PATH=$(pwd -P)
ROOT_REAL_PATH=$(dirname "$COMMON_REAL_PATH")
KCFLAGS+=" -fdebug-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -fmacro-prefix-map=$ROOT_REAL_PATH=."
KCFLAGS+=" -ffile-prefix-map=$ROOT_REAL_PATH=."
# FinaSU：以绝对路径注入驱动与 SELinux 头文件搜索目录
if [ -n "${KSU_INC_DIR:-}" ]; then
  KCFLAGS+=" -I$KSU_INC_DIR -I$KSU_INC_DIR/include"
  KCFLAGS+=" -I$ROOT_REAL_PATH/security/selinux -I$ROOT_REAL_PATH/security/selinux/include"
  KCFLAGS+=" -I$COMMON_REAL_PATH/out/security/selinux -I$COMMON_REAL_PATH/out/security/selinux/include"
fi
export KCFLAGS
source "./_setup_env.sh" 2>/dev/null || true
echo "KCFLAGS=$KCFLAGS"

make -j$(nproc --all) \
    LLVM=1 \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CC="$CLANG_DIR/clang" \
    HOSTCC="$CLANG_DIR/clang" \
    LD=ld.lld \
    HOSTLD=ld.lld \
    RUSTC="rustc" \
    OBJCOPY="llvm-objcopy" \
    O=out \
    gki_defconfig Image 2>&1 | tee $WORKDIR/build.log
echo ">>> 内核编译成功！"

# ===== 选择使用 patch_linux (KPM补丁)=====
WORKDIR="$SCRIPT_DIR"
OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  echo ">>> 使用 kptools-linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KP-N补丁!"
fi

# ===== 克隆并打包 AnyKernel3 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1

echo ">>> 清理 AnyKernel3 Git 信息..."
rm -rf ./AnyKernel3/.git

echo ">>> 拷贝内核镜像到 AnyKernel3 目录..."
cp "$OUT_DIR/Image" ./AnyKernel3/

echo ">>> 进入 AnyKernel3 目录并打包 zip..."
cd "$WORKDIR/kernel_workspace/AnyKernel3"

# ===== 如果启用 lz4kd，则下载 zram.zip 并放入当前目录 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8850/refs/heads/main/zram.zip
fi

if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  wget https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip
fi

# ===== 生成 ZIP 文件名 =====
ZIP_NAME="Anykernel3-${MANIFEST}"

if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbr"
fi
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  ZIP_NAME="${ZIP_NAME}-dss"
fi
if [[ "$APPLY_ADIOS" == "y" || "$APPLY_ADIOS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-adios"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi

ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

# ===== 打包 ZIP 文件，包括 zram.zip（如果存在） =====
echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*

ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"
