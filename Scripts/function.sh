#!/bin/bash
# =====================================
# 功能函数库脚本
# 此脚本包含构建OpenWRT过程中使用的各种功能函数
# =====================================

# ========== 内核配置相关函数 ==========

# 函数: cat_kernel_config
# 用途: 向指定的内核配置文件添加eBPF和性能优化相关的配置选项
# 参数: $1 - 目标配置文件路径
function cat_kernel_config() {
  if [ -f $1 ]; then
    cat >> $1 <<EOF
# eBPF支持配置
CONFIG_BPF=y                    # 启用eBPF支持
CONFIG_BPF_SYSCALL=y            # 启用eBPF系统调用
CONFIG_BPF_JIT=y                # 启用eBPF即时编译
CONFIG_CGROUPS=y                # 启用控制组
CONFIG_KPROBES=y                # 启用内核探针
CONFIG_NET_INGRESS=y            # 启用网络入口处理
CONFIG_NET_EGRESS=y             # 启用网络出口处理
CONFIG_NET_SCH_INGRESS=m        # 网络入口调度模块
CONFIG_NET_CLS_BPF=m            # 基于eBPF的流量分类
CONFIG_NET_CLS_ACT=y            # 启用流量控制动作
CONFIG_BPF_STREAM_PARSER=y      # eBPF流解析器

# 调试信息配置
CONFIG_DEBUG_INFO=y             # 启用调试信息
# CONFIG_DEBUG_INFO_REDUCED is not set
CONFIG_DEBUG_INFO_BTF=y         # 启用BPF类型格式调试信息
CONFIG_KPROBE_EVENTS=y          # 启用kprobe事件
CONFIG_BPF_EVENTS=y             # 启用eBPF事件

# 性能优化配置
CONFIG_SCHED_CLASS_EXT=y        # 调度器类扩展
CONFIG_PROBE_EVENTS_BTF_ARGS=y  # BTF参数探测
CONFIG_IMX_SCMI_MISC_DRV=y      # IMX SCMI驱动
CONFIG_ARM64_CONTPTE=y          # ARM64连续页表
CONFIG_TRANSPARENT_HUGEPAGE=y   # 透明大页支持
CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y  # 始终使用透明大页
# CONFIG_TRANSPARENT_HUGEPAGE_MADVISE is not set
# CONFIG_TRANSPARENT_HUGEPAGE_NEVER is not set
EOF
    echo "cat_kernel_config to $1 done"
  fi
}

# 函数: cat_ebpf_config
# 用途: 向配置文件添加eBPF开发环境相关配置
# 参数: $1 - 目标配置文件路径
function cat_ebpf_config() {
  cat >> $1 <<EOF
# ========== eBPF开发环境配置 ==========
CONFIG_DEVEL=y                      # 开发模式
CONFIG_KERNEL_DEBUG_INFO=y          # 内核调试信息
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n  # 不使用简化调试信息
CONFIG_KERNEL_DEBUG_INFO_BTF=y      # BTF调试信息
CONFIG_KERNEL_CGROUPS=y             # 内核控制组
CONFIG_KERNEL_CGROUP_BPF=y          # 控制组BPF
CONFIG_KERNEL_BPF_EVENTS=y          # 内核BPF事件
CONFIG_BPF_TOOLCHAIN_HOST=y         # 主机BPF工具链
CONFIG_KERNEL_XDP_SOCKETS=y         # 内核XDP套接字
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y  # XDP套接字诊断
EOF
}

# ========== 硬件驱动相关函数 ==========

# 函数: cat_usb_net
# 用途: 向配置文件添加USB网络设备驱动支持
# 参数: $1 - 目标配置文件路径
function cat_usb_net() {
  cat >> $1 <<EOF
# ========== USB网络设备驱动 ==========
CONFIG_PACKAGE_kmod-usb-net=y              # 基础USB网络支持
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y      # CDC EEM协议
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y    # CDC以太网
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y     # MBIM协议
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y      # CDC NCM协议
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y   # CDC子集协议
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y  # 华为CDC NCM
CONFIG_PACKAGE_kmod-usb-net-ipheth=y       # iPhone USB网络
CONFIG_PACKAGE_kmod-usb-net-rndis=y        # RNDIS协议
CONFIG_PACKAGE_kmod-usb-net-rtl8150=y      # RTL8150 USB网卡
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y      # RTL8152 USB网卡
EOF

  # 6.12内核不包含以下驱动
  if echo "$CI_NAME" | grep -v "6.12" > /dev/null; then
    cat >> $1 <<EOF
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y        # QMI WWAN
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-fibocom=y # 广和通QMI WWAN
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-quectel=y # 移远QMI WWAN
EOF
  fi
}

# 函数: set_nss_driver
# 用途: 配置高通NSS（网络子系统）驱动
# 参数: $1 - 目标配置文件路径
function set_nss_driver() {
  cat >> $1 <<EOF
# ========== 高通NSS驱动配置 ==========
# NSS固件版本选择
CONFIG_NSS_FIRMWARE_VERSION_11_4=n
# CONFIG_NSS_FIRMWARE_VERSION_12_5 is not set
CONFIG_NSS_FIRMWARE_VERSION_12_2=y   # 使用NSS固件12.2版本

# NSS核心驱动
CONFIG_PACKAGE_kmod-qca-nss-dp=y      # NSS数据路径驱动
CONFIG_PACKAGE_kmod-qca-nss-drv=y     # NSS主驱动
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y  # 桥接管理
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan=y        # VLAN支持
CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y         # 组播抑制
# CONFIG_PACKAGE_kmod-qca-nss-drv-map-t=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y       # PPPoE加速
CONFIG_PACKAGE_kmod-qca-nss-drv-pptp=y        # PPTP加速
CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y       # QoS调度器
CONFIG_PACKAGE_kmod-qca-nss-ecm=y             # 以太网连接管理器
CONFIG_PACKAGE_kmod-qca-nss-macsec=y          # MACsec支持
CONFIG_PACKAGE_kmod-qca-nss-drv-l2tpv2=y      # L2TPv2加速
CONFIG_PACKAGE_kmod-qca-nss-drv-lag-mgr=y     # 链路聚合管理
EOF
}

# ========== 辅助函数 ==========

# 函数: kernel_version
# 用途: 获取当前内核版本
# 返回值: 内核版本号
function kernel_version() {
  echo $(sed -n 's/^KERNEL_PATCHVER:=\(.*\)/\1/p' target/linux/qualcommax/Makefile)
}

# 函数: remove_wifi
# 用途: 移除指定目标平台的WiFi相关组件
# 参数: $1 - 目标平台名称
function remove_wifi() {
  local target=$1
  # 去除WiFi相关依赖
  sed -i 's/\(ath11k-firmware-[^ ]*\|ipq-wifi-[^ ]*\|kmod-ath11k-[^ ]*\)//g' ./target/linux/qualcommax/Makefile
  sed -i 's/\(ath11k-firmware-[^ ]*\|ipq-wifi-[^ ]*\|kmod-ath11k-[^ ]*\)//g' ./target/linux/qualcommax/${target}/target.mk
  sed -i 's/\(ath11k-firmware-[^ ]*\|ipq-wifi-[^ ]*\|kmod-ath11k-[^ ]*\)//g' ./target/linux/qualcommax/image/${target}.mk
  sed -i 's/\(ath10k-firmware-[^ ]*\|kmod-ath10k [^ ]*\|kmod-ath10k-[^ ]*\)//g' ./target/linux/qualcommax/image/${target}.mk
  
  # 删除无线组件
  rm -rf package/network/services/hostapd
  rm -rf package/firmware/ipq-wifi
}

# 函数: set_kernel_size
# 用途: 修改指定设备的内核分区大小
# 说明: 将多个设备的内核分区从6MB或8MB增加到12MB，以支持更多功能
function set_kernel_size() {
  image_file='./target/linux/qualcommax/image/ipq60xx.mk'
  # 修改京东云设备内核大小为12M
  sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  # 修改Linksys设备内核大小为12M
  sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
}

# ========== 性能优化函数 ==========

# 函数: enable_skb_recycler
# 用途: 启用网络缓冲区回收补丁，提高网络性能
# 参数: $1 - 目标配置文件路径
function enable_skb_recycler() {
  cat >> $1 <<EOF
# ========== 网络缓冲区回收优化 ==========
CONFIG_KERNEL_SKB_RECYCLER=y            # 启用SKB回收器
CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y  # 多核SKB回收支持
EOF
}

# ========== 主配置生成函数 ==========

# 函数: generate_config
# 用途: 生成完整的OpenWRT配置文件
# 环境变量: 
#   - GITHUB_WORKSPACE: GitHub工作空间路径
#   - WRT_CONFIG: 配置文件名称
#   - WRT_ARCH: 架构信息
function generate_config() {
  config_file=".config"
  
  # 合并基本配置和通用配置
  cat $GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt $GITHUB_WORKSPACE/Config/GENERAL.txt  > $config_file
  
  # 提取目标平台
  local target=$(echo $WRT_ARCH | cut -d'_' -f2)

  # 如果是无WiFi版本，则移除WiFi依赖
  if [[ "$WRT_CONFIG" == *"NOWIFI"* ]]; then
    remove_wifi $target
  fi

  # IPK仓库特殊处理
  if [[ "${GITHUB_REPOSITORY,,}" == *"openwrt-ci-ipk"* ]]; then
    echo "CONFIG_USE_APK=n" >> $config_file
  fi

  # 添加NSS驱动配置
  set_nss_driver $config_file
  
  # 添加eBPF配置
  cat_ebpf_config $config_file
  
  # 启用SKB回收器
  enable_skb_recycler $config_file
  
  # 设置内核大小
  set_kernel_size
  
  # 添加内核选项到默认配置
  cat_kernel_config "target/linux/qualcommax/${target}/config-default"
}






