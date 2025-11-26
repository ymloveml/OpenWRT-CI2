#!/bin/bash

# 源码仓库配置 - 以下是可选的源码仓库，当前启用VIKINGYFY的immortalwrt仓库
WRT_REPO='https://github.com/LiBwrt/openwrt-6.x'
WRT_BRANCH='k6.12-nss'

#WRT_REPO='https://github.com/davidtall/immortalwrt-6.12'
#WRT_BRANCH='main'

#WRT_REPO='https://github.com/VIKINGYFY/immortalwrt'  # 当前使用的源码仓库
#WRT_BRANCH='main'  # 当前使用的分支

if [ -n "$1" ]; then
    # 如果有传递参数，赋值给WRT_TARGET
    filename=$(basename "$1")
    export WRT_CONFIG="${filename%.*}"  # 从文件名中提取配置名称（去掉扩展名）
else
    # 如果没有传递参数，设置默认值
    export WRT_CONFIG="IPQ60XX-NOWIFI"  # 默认配置文件名
fi

if [ -n "$2" ]; then
    WRT_REPO="$2"  # 如果提供了第二个参数，使用它作为仓库地址
fi

# 设置环境变量
export WRT_DIR=wrt  # OpenWrt源码目录名
export GITHUB_WORKSPACE=$(pwd)  # 当前工作目录
export WRT_DATE=$(TZ=UTC-8 date +"%y.%m.%d_%H.%M.%S")  # 编译日期时间（北京时间）
export WRT_VER=$(echo $WRT_REPO | cut -d '/' -f 5-)-$WRT_BRANCH  # 版本标识（仓库名-分支名）
export WRT_TYPE=$(sed -n "1{s/^#//;s/\r$//;p;q}" $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt)  # 从配置文件第一行提取类型信息
export WRT_NAME='OWRT'  # 固件名称前缀
export WRT_SSID='2019'  # 默认WiFi名称
export WRT_WORD='13410447748'  # 默认密码
export WRT_THEME='argon'  # Web界面主题
export WRT_IP='192.168.2.1'  # 路由器默认IP地址
export WRT_CI='WSL-OpenWRT-CI'  # CI环境标识
export WRT_ARCH=$(sed -n 's/.*_DEVICE_\(.*\)_DEVICE_.*/\1/p' $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt | head -n 1)  # 从配置文件提取架构信息
export CI_NAME='QCA-6.12-LiBwrt'  # CI任务名称
export WRT_TARGET=$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt | tr '[:lower:]' '[:upper:]')  # 从配置文件提取目标平台

. $GITHUB_WORKSPACE/Scripts/function.sh  # 引入通用函数脚本

# 处理源码目录
if [ ! -d $WRT_DIR ]; then
  # 如果源码目录不存在，克隆源码
  git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO $WRT_DIR
  cd $WRT_DIR
else
  # 如果源码目录已存在，更新源码
  cd $WRT_DIR
  git remote set-url origin $WRT_REPO  # 更新远程仓库地址
  rm -rf feeds/*  # 删除旧的feeds
  git clean -f  # 清理未跟踪的文件
  git reset --hard  # 重置工作目录到最新提交
  git pull  # 拉取最新代码
fi

# 更新并安装feeds
echo "更新并安装feeds..."
./scripts/feeds update -a && ./scripts/feeds install -a

# 处理软件包
cd package/
$GITHUB_WORKSPACE/Scripts/Packages.sh  # 执行软件包相关脚本
$GITHUB_WORKSPACE/Scripts/Handles.sh  # 执行额外处理脚本

# Docker相关处理说明
# Docker支持包已经在Config目录下的配置文件中定义，包括:
# - 核心包: docker, docker-compose, dockerd等
# - 所需内核模块: OverlayFS, macvlan, veth等
# - Web管理界面: luci-app-dockerman

cd ..

# 生成配置文件
echo "生成配置文件..."
generate_config

# 执行额外设置
$GITHUB_WORKSPACE/Scripts/Settings.sh  # 应用额外设置

# 生成默认配置
echo "生成默认配置..."
make defconfig

# 以下是可选的编译命令，当前被注释掉
# make download -j8  # 下载依赖（8线程）
# make -j$(nproc) || make V=s -j1  # 编译，失败时启用详细输出单线程重新编译

# make download -j8 && (make -j$(nproc) || make V=s -j1)  # 组合下载和编译命令
