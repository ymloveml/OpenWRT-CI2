#!/bin/bash
# =====================================
# 软件包管理脚本(Packages.sh)
# 此脚本用于管理OpenWRT构建过程中的软件包安装、更新和修复
# =====================================

# ========== 软件包更新函数 ==========

# 函数: UPDATE_PACKAGE
# 用途: 从GitHub克隆并更新指定的软件包
# 参数:
#   $1 - 包名(PKG_NAME)
#   $2 - GitHub仓库路径(PKG_REPO)
#   $3 - 分支名(PKG_BRANCH)
#   $4 - 特殊处理标志(PKG_SPECIAL, pkg:从大杂烩中提取, name:重命名)
#   $5 - 自定义名称列表(可选)
function UPDATE_PACKAGE() {
	local PKG_NAME=$1                # 主包名
	local PKG_REPO=$2                # GitHub仓库(用户名/仓库名)
	local PKG_BRANCH=$3              # 仓库分支
	local PKG_SPECIAL=$4             # 特殊处理标志
	local PKG_LIST=("$PKG_NAME" $5)  # 包名列表(包含主包名和别名)
	local REPO_NAME=${PKG_REPO#*/}   # 从仓库路径中提取仓库名称

	echo " "

	# 删除本地可能存在的旧版本软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
		done

	# 从GitHub克隆最新版本的仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 根据特殊标志处理克隆的仓库
	if [[ $PKG_SPECIAL == "pkg" ]]; then
		# 从大杂烩仓库中提取特定软件包
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		# 清理临时仓库目录
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		# 将仓库重命名为指定的包名
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# ========== 软件包版本更新函数 ==========

# 函数: UPDATE_VERSION
# 用途: 更新软件包到最新版本
# 参数:
#   $1 - 包名
#   $2 - 是否包含预发布版本(true/false，默认false)
function UPDATE_VERSION() {
	local PKG_NAME=$1               # 包名
	local PKG_MARK=${2:-false}      # 是否包含预发布版本
	# 查找Makefile文件
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	# 处理每个找到的Makefile
	for PKG_FILE in $PKG_FILES; do
		# 从Makefile中提取GitHub仓库信息
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		# 通过GitHub API获取最新版本标签
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		# 提取当前版本信息
		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		# 构建源文件URL
		local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		# 处理新版本号和URL
		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		# 计算新源文件的哈希值
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		# 显示版本信息
		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		# 比较版本并更新
		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
		done
}

# ========== 主题和界面相关 ==========

# 安装Argon主题
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js" # 可选的Kucat主题

# ========== 代理和网络工具 ==========

# 安装HomeProxy代理工具
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

# 安装其他代理相关组件
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"

# 以下是其他可选代理工具（当前被注释）
# UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
# UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
# UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"

# ========== 其他功能插件 ==========

# UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main" # TailScale（可选）
# UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main" # Alist文件列表（可选）

# 安装DDNS-Go（动态DNS工具）
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"

# 安装EasyTier（P2P组网工具）
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"

# 安装GECOOSAC（网络加速工具）
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"

# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat" # DNS分流器（可选）

# 安装网络测速工具
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"

# 安装分区扩展工具
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"

# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent" # BT下载（可选）
# UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main" # 调制解调器工具（可选）

# 安装定时唤醒工具
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"

# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main" # VNT工具（可选）

# ========== 核心功能插件 ==========

# 安装daed代理工具Web界面
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"

# 安装推送机器人
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

# ========== 版本更新调用（当前被注释） ==========

# UPDATE_VERSION "sing-box" # 更新sing-box版本
# UPDATE_VERSION "tailscale" # 更新tailscale版本

# ========== 配置和修复 ==========

# 不编译xray-core（如果不需要可以节省空间）
sed -i 's/+xray-core//' luci-app-passwall2/Makefile

# 删除官方默认的相关插件，避免冲突
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

# 更新Golang为最新版本
rm -rf ../feeds/packages/lang/golang
git clone -b 24.x https://github.com/sbwml/packages_lang_golang ../feeds/packages/lang/golang

# 复制项目自定义包
cp -r $GITHUB_WORKSPACE/package/* ./

# 修复coremark构建错误
# 将mkdir改为mkdir -p以确保父目录存在
 sed -i 's/mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/mkdir -p \$(PKG_BUILD_DIR)\/\$(ARCH)/g' ../feeds/packages/utils/coremark/Makefile

# 修改Argon主题字体样式
argon_css_file=$(find ./luci-theme-argon/ -type f -name "cascade.css")
sed -i "/^.main .main-left .nav li a {/,/^}/ { /font-weight: bolder/d }" $argon_css_file
# 调整OPKG页面的字体权重
 sed -i '/^\[data-page="admin-system-opkg"\] #maincontent>.container {/,/}/ s/font-weight: 600;/font-weight: normal;/' $argon_css_file

# 修复daed的Makefile
rm -rf luci-app-daed/daed/Makefile && cp -r $GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/
cat luci-app-daed/daed/Makefile # 显示修复后的Makefile内容
