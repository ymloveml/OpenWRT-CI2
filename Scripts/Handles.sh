#!/bin/bash
# =====================================
# 处理脚本(Handles.sh)
# 此脚本用于处理OpenWRT构建过程中的各种调整和修复
# =====================================

# 设置包路径环境变量
PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

# ========== 预置HomeProxy数据 ==========
# 如果检测到homeproxy目录存在，则更新其规则数据
if [ -d *"homeproxy"* ]; then
	echo " "

	# 定义变量
	HP_RULE="surge"         # 规则类型
	HP_PATH="homeproxy/root/etc/homeproxy"  # HomeProxy配置路径

	# 清空现有资源目录
	rm -rf ./$HP_PATH/resources/*

	# 克隆surge规则仓库（只获取最新版本）
	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	
	# 进入规则目录并提取版本号
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	# 创建版本文件
	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	
	# 处理IP规则文件
	# 从cncidr.txt中提取IPv4和IPv6的CIDR
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	
	# 处理域名规则文件，移除开头的点号
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	
	# 移动生成的规则文件到HomeProxy资源目录
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	# 清理临时目录
	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

# ========== 修改高通NSS驱动启动顺序 ==========
# 调整qca-nss-drv的启动顺序，确保它在正确的时机启动
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	# 设置启动顺序为85（数字越大，启动越晚）
	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

# ========== 修改NSS缓冲区启动顺序 ==========
# 调整qca-nss-pbuf的启动顺序，确保它在qca-nss-drv之后启动
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	# 设置启动顺序为86（在qca-nss-drv之后）
	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

# ========== 修复TailScale配置文件冲突 ==========
# 查找并修复TailScale的Makefile，解决可能的配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	# 删除可能导致冲突的/files目录引用
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi
