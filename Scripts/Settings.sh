#!/bin/bash
# =====================================
# 系统设置脚本(Settings.sh)
# 此脚本用于配置OpenWRT系统的默认设置，包括主题、IP地址、WIFI参数等
# =====================================

# 导入功能函数库
. $(dirname "$(realpath "$0")")/function.sh

# ========== Web界面配置 ==========

# 修改默认主题为指定的主题
# 替换feeds/luci/collections目录下所有Makefile中的默认主题
 sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 修改immortalwrt.lan关联的默认IP地址
# 在flash.js文件中更新关联的IP地址
 sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

# 添加编译日期标识到系统信息中
# 在10_system.js中添加DaeWRT版本和日期信息
 sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ DaeWRT-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# ========== WIFI配置 ==========

# 查找WIFI配置文件路径
# 尝试在mediatek/filogic和qualcommax平台查找set-wireless.sh
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
# 备用WIFI配置文件路径
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -f "$WIFI_SH" ]; then
	# 在set-wireless.sh中修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	# 修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	# 在mac80211.uc中修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	# 修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	# 修改WIFI地区为中国
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	# 设置WIFI加密方式为PSK2+CCMP
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

# ========== 基础系统配置 ==========

# 定义配置文件路径
CFG_FILE="./package/base-files/files/bin/config_generate"

# 修改默认IP地址
# 在config_generate文件中更新默认的LAN口IP地址
 sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE

# 修改默认主机名
# 在config_generate文件中设置自定义主机名
 sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# ========== 补丁和修复 ==========

# 为vlmcsd服务添加编译修复补丁
vlmcsd_patches="./feeds/packages/net/vlmcsd/patches/"
mkdir -p $vlmcsd_patches && cp -f ../patches/001-fix_compile_with_ccache.patch $vlmcsd_patches

# 修复dropbear SSH服务器配置
# 移除Interface配置行以避免潜在的冲突问题
# sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config
sed -i "/Interface/d" ./package/network/services/dropbear/files/dropbear.config

# 拷贝自定义文件到编译目录
# 将项目根目录的files文件夹复制到当前编译目录
cp -r ../files ./

# ========== 配置文件调整 ==========

# 以下配置已注释，可根据需要取消注释启用
# echo "CONFIG_PACKAGE_luci=y" >> ./.config               # 确保安装luci
# echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config        # 安装中文语言包
# echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config  # 安装指定主题
# echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config  # 安装主题配置插件

# ========== 自定义软件包 ==========

# 如果设置了手动调整的插件列表，则添加到配置文件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# ========== 高通平台特殊配置 ==========

# 定义高通平台DTS文件路径
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"

# 针对高通平台的特殊调整
if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
	# 取消默认的nss相关feed，避免冲突
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	
	# 设置NSS固件版本为12.5
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	
	# 开启SQM QoS和SQM-NSS插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	
	# 无WIFI配置的特殊处理
	# 如果配置名称包含"wifi"和"no"，则使用无WIFI的DTS文件
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		# 将默认DTS文件替换为无WIFI版本
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
