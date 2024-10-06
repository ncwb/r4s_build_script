#!/bin/bash -e

# Rockchip - rkbin & u-boot
rm -rf package/boot/rkbin package/boot/uboot-rockchip package/boot/arm-trusted-firmware-rockchip
if [ "$platform" = "rk3568" ]; then
    git clone https://$github/sbwml/package_boot_uboot-rockchip package/boot/uboot-rockchip
    git clone https://$github/sbwml/arm-trusted-firmware-rockchip package/boot/arm-trusted-firmware-rockchip
else
    git clone https://$github/sbwml/package_boot_uboot-rockchip package/boot/uboot-rockchip -b v2023.04
    git clone https://$github/sbwml/arm-trusted-firmware-rockchip package/boot/arm-trusted-firmware-rockchip -b 0419
fi

######## OpenWrt Patches ########

[ "$version" = "rc2" ] && generic=generic || generic=generic-24.10

# tools: add llvm/clang toolchain
curl -s https://$mirror/openwrt/patch/$generic/0001-tools-add-llvm-clang-toolchain.patch | patch -p1

# tools: add upx tools
curl -s https://$mirror/openwrt/patch/$generic/0002-tools-add-upx-tools.patch | patch -p1

# rootfs: upx compression
# include/rootfs.mk
curl -s https://$mirror/openwrt/patch/$generic/0003-rootfs-add-upx-compression-support.patch | patch -p1

# rootfs: add r/w (0600) permissions for UCI configuration files
# include/rootfs.mk
curl -s https://$mirror/openwrt/patch/$generic/0004-rootfs-add-r-w-permissions-for-UCI-configuration-fil.patch | patch -p1

# rootfs: Add support for local kmod installation sources
curl -s https://$mirror/openwrt/patch/$generic/0005-rootfs-Add-support-for-local-kmod-installation-sourc.patch | patch -p1

# BTF: fix failed to validate module
# config/Config-kernel.in patch
curl -s https://$mirror/openwrt/patch/$generic/0006-kernel-add-MODULE_ALLOW_BTF_MISMATCH-option.patch | patch -p1

# kernel: Add support for llvm/clang compiler
curl -s https://$mirror/openwrt/patch/$generic/0007-kernel-Add-support-for-llvm-clang-compiler.patch | patch -p1

# toolchain: Add libquadmath to the toolchain
curl -s https://$mirror/openwrt/patch/$generic/0008-libquadmath-Add-libquadmath-to-the-toolchain.patch | patch -p1

# build: kernel: add out-of-tree kernel config
curl -s https://$mirror/openwrt/patch/$generic/0009-build-kernel-add-out-of-tree-kernel-config.patch | patch -p1

# kernel: linux-6.11 config
curl -s https://$mirror/openwrt/patch/$generic/0010-include-kernel-add-miss-config-for-linux-6.11.patch | patch -p1

# meson: add platform variable to cross-compilation file
curl -s https://$mirror/openwrt/patch/$generic/0011-meson-add-platform-variable-to-cross-compilation-fil.patch | patch -p1

# mold
if [ "$ENABLE_MOLD" = "y" ] && [ "$version" = "rc2" ]; then
    curl -s https://$mirror/openwrt/patch/generic/mold/0001-build-add-support-to-use-the-mold-linker-for-package.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0002-treewide-opt-out-of-tree-wide-mold-usage.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0003-toolchain-add-mold-as-additional-linker.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0004-tools-add-mold-a-modern-linker.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0005-build-replace-SSTRIP_ARGS-with-SSTRIP_DISCARD_TRAILI.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0006-config-add-a-knob-to-use-the-mold-linker-for-package.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0007-rules-prepare-to-use-different-linkers.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/mold/0008-tools-mold-update-to-2.34.1.patch | patch -p1
fi
[ "$version" = "snapshots-24.10" ] && curl -s https://$mirror/openwrt/patch/generic-24.10/203-tools-mold-update-to-2.34.1.patch | patch -p1

# attr no-mold
[ "$ENABLE_MOLD" = "y" ] && sed -i '/PKG_BUILD_PARALLEL/aPKG_BUILD_FLAGS:=no-mold' feeds/packages/utils/attr/Makefile

######## OpenWrt Patches End ########

# dwarves: Fix a dwarf type DW_ATE_unsigned_1024 to btf encoding issue
if [ "$version" = "rc2" ]; then
    mkdir -p tools/dwarves/patches
    curl -s https://$mirror/openwrt/patch/openwrt-6.x/dwarves/100-btf_encoder-Fix-a-dwarf-type-DW_ATE_unsigned_1024-to-btf-encoding-issue.patch > tools/dwarves/patches/100-btf_encoder-Fix-a-dwarf-type-DW_ATE_unsigned_1024-to-btf-encoding-issue.patch
fi

# dwarves 1.25
if [ "$version" = "snapshots-24.10" ]; then
    rm -rf tools/dwarves
    git clone https://$github/sbwml/tools_dwarves tools/dwarves
fi

# x86 - disable intel_pstate & mitigations
sed -i 's/noinitrd/noinitrd intel_pstate=disable mitigations=off/g' target/linux/x86/image/grub-efi.cfg

# default LAN IP
sed -i "s/192.168.1.1/$LAN/g" package/base-files/files/bin/config_generate

# Use nginx instead of uhttpd
if [ "$ENABLE_UHTTPD" != "y" ]; then
    sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci/Makefile
    sed -i 's/+uhttpd-mod-ubus //' feeds/luci/collections/luci/Makefile
    sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci-light/Makefile
    sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl-openssl/Makefile
    sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl/Makefile
    if [ "$version" = "snapshots-24.10" ] || [ "$version" = "rc2" ]; then
        sed -i 's/+uhttpd +uhttpd-mod-ubus /+luci-nginx /g' feeds/packages/net/wg-installer/Makefile
        sed -i '/uhttpd-mod-ubus/d' feeds/luci/collections/luci-light/Makefile
        sed -i 's/+luci-nginx \\$/+luci-nginx/' feeds/luci/collections/luci-light/Makefile
    fi
fi

# Realtek driver - R8168 & R8125 & R8126 & R8152 & R8101
rm -rf package/kernel/r8168 package/kernel/r8101 package/kernel/r8125 package/kernel/r8126
git clone https://$github/sbwml/package_kernel_r8168 package/kernel/r8168
git clone https://$github/sbwml/package_kernel_r8152 package/kernel/r8152
git clone https://$github/sbwml/package_kernel_r8101 package/kernel/r8101
git clone https://$github/sbwml/package_kernel_r8125 package/kernel/r8125
git clone https://$github/sbwml/package_kernel_r8126 package/kernel/r8126

# GCC Optimization level -O3
if [ "$platform" = "x86_64" ]; then
    curl -s https://$mirror/openwrt/patch/target-modify_for_x86_64.patch | patch -p1
elif [ "$platform" = "armv8" ]; then
    curl -s https://$mirror/openwrt/patch/target-modify_for_armsr.patch | patch -p1
else
    curl -s https://$mirror/openwrt/patch/target-modify_for_rockchip.patch | patch -p1
fi

# DPDK & NUMACTL
if [ "$ENABLE_DPDK" = "y" ]; then
    mkdir -p package/new/{dpdk/patches,numactl}
    curl -s https://$mirror/openwrt/patch/dpdk/dpdk/Makefile > package/new/dpdk/Makefile
    curl -s https://$mirror/openwrt/patch/dpdk/dpdk/Config.in > package/new/dpdk/Config.in
    curl -s https://$mirror/openwrt/patch/dpdk/dpdk/patches/010-dpdk_arm_build_platform_fix.patch > package/new/dpdk/patches/010-dpdk_arm_build_platform_fix.patch
    curl -s https://$mirror/openwrt/patch/dpdk/dpdk/patches/201-r8125-add-r8125-ethernet-poll-mode-driver.patch > package/new/dpdk/patches/201-r8125-add-r8125-ethernet-poll-mode-driver.patch
    curl -s https://$mirror/openwrt/patch/dpdk/numactl/Makefile > package/new/numactl/Makefile
fi

# IF USE GLIBC
if [ "$ENABLE_GLIBC" = "y" ]; then
    # musl-libc
    git clone https://$gitea/sbwml/package_libs_musl-libc package/libs/musl-libc
    # bump fstools version
    [ "$version" = "rc2" ] && rm -rf package/system/fstools
    [ "$version" = "rc2" ] && cp -a ../master/openwrt/package/system/fstools package/system/fstools
    # glibc-common
    curl -s https://$mirror/openwrt/patch/glibc/glibc-common.patch | patch -p1
    # glibc-common - locale data
    mkdir -p package/libs/toolchain/glibc-locale
    curl -Lso package/libs/toolchain/glibc-locale/locale-archive https://github.com/sbwml/r4s_build_script/releases/download/locale/locale-archive
    [ "$?" -ne 0 ] && echo -e "${RED_COLOR} Locale file download failed... ${RES}"
    # GNU LANG
    mkdir package/base-files/files/etc/profile.d
    echo 'export LANG="en_US.UTF-8" I18NPATH="/usr/share/i18n"' > package/base-files/files/etc/profile.d/sys_locale.sh
    # build - drop `--disable-profile`
    sed -i "/disable-profile/d" toolchain/glibc/common.mk
fi

# Mbedtls AES & GCM Crypto Extensions
if [ ! "$platform" = "x86_64" ] && [ "$version" = "rc2" ]; then
    curl -s https://$mirror/openwrt/patch/mbedtls-23.05/200-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch > package/libs/mbedtls/patches/200-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch
    curl -s https://$mirror/openwrt/patch/mbedtls-23.05/mbedtls.patch | patch -p1
fi

if [ "$version" = "rc2" ]; then
    # util-linux - ntfs3
    mkdir -p package/utils/util-linux/patches
    curl -s https://$mirror/openwrt/patch/util-linux/201-util-linux_ntfs3.patch > package/utils/util-linux/patches/201-util-linux_ntfs3.patch
    # fstools - enable any device with non-MTD rootfs_data volume
    curl -s https://$mirror/openwrt/patch/fstools/Makefile > package/system/fstools/Makefile
    sed -i 's|$(PROJECT_GIT)/project|https://github.com/openwrt|g' package/system/fstools/Makefile
    mkdir -p package/system/fstools/patches
    curl -s https://$mirror/openwrt/patch/fstools/200-use-ntfs3-instead-of-ntfs.patch > package/system/fstools/patches/200-use-ntfs3-instead-of-ntfs.patch
    curl -s https://$mirror/openwrt/patch/fstools/201-fstools-set-ntfs3-utf8.patch > package/system/fstools/patches/201-fstools-set-ntfs3-utf8.patch
    if [ "$ENABLE_GLIBC" = "y" ]; then
        curl -s https://$mirror/openwrt/patch/fstools/glibc/0001-libblkid-tiny-add-support-for-XFS-superblock.patch > package/system/fstools/patches/0001-libblkid-tiny-add-support-for-XFS-superblock.patch
        curl -s https://$mirror/openwrt/patch/fstools/glibc/0003-block-add-xfsck-support.patch > package/system/fstools/patches/0003-block-add-xfsck-support.patch
        curl -s https://$mirror/openwrt/patch/fstools/202-fstools-support-extroot-for-non-MTD-rootfs_data-new-version.patch > package/system/fstools/patches/202-fstools-support-extroot-for-non-MTD-rootfs_data.patch
    else
        curl -s https://$mirror/openwrt/patch/fstools/202-fstools-support-extroot-for-non-MTD-rootfs_data.patch > package/system/fstools/patches/202-fstools-support-extroot-for-non-MTD-rootfs_data.patch
    fi
else
    # fstools
    rm -rf package/system/fstools
    git clone https://$github/sbwml/package_system_fstools -b openwrt-24.10 package/system/fstools
    # util-linux
    rm -rf package/utils/util-linux
    git clone https://$github/sbwml/package_utils_util-linux -b openwrt-24.10 package/utils/util-linux
fi

# Shortcut Forwarding Engine
git clone https://$gitea/sbwml/shortcut-fe package/new/shortcut-fe

# Patch FireWall 4
if [ "$version" = "snapshots-24.10" ] || [ "$version" = "rc2" ]; then
    # firewall4 - master
    [ "$version" = "rc2" ] && rm -rf package/network/config/firewall4
    [ "$version" = "rc2" ] && cp -a ../master/openwrt/package/network/config/firewall4 package/network/config/firewall4
    sed -i 's|$(PROJECT_GIT)/project|https://github.com/openwrt|g' package/network/config/firewall4/Makefile
    mkdir -p package/network/config/firewall4/patches
    # fix ct status dnat
    curl -s https://$mirror/openwrt/patch/firewall4/firewall4_patches/990-unconditionally-allow-ct-status-dnat.patch > package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
    # fullcone
    curl -s https://$mirror/openwrt/patch/firewall4/firewall4_patches/999-01-firewall4-add-fullcone-support.patch > package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
    # bcm fullcone
    [ "$TESTING_KERNEL" != "y" ] && curl -s https://$mirror/openwrt/patch/firewall4/firewall4_patches/999-02-firewall4-add-bcm-fullconenat-support.patch > package/network/config/firewall4/patches/999-02-firewall4-add-bcm-fullconenat-support.patch
    # kernel version
    curl -s https://$mirror/openwrt/patch/firewall4/firewall4_patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch > package/network/config/firewall4/patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch
    # fix flow offload
    curl -s https://$mirror/openwrt/patch/firewall4/firewall4_patches/001-fix-fw4-flow-offload.patch > package/network/config/firewall4/patches/001-fix-fw4-flow-offload.patch
    # add custom nft command support
    curl -s https://$mirror/openwrt/patch/firewall4/100-openwrt-firewall4-add-custom-nft-command-support.patch | patch -p1
    # libnftnl
    [ "$version" = "rc2" ] && rm -rf package/libs/libnftnl
    [ "$version" = "rc2" ] && cp -a ../master/openwrt/package/libs/libnftnl package/libs/libnftnl
    mkdir -p package/libs/libnftnl/patches
    curl -s https://$mirror/openwrt/patch/firewall4/libnftnl/001-libnftnl-add-fullcone-expression-support.patch > package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch
    [ "$TESTING_KERNEL" != "y" ] && curl -s https://$mirror/openwrt/patch/firewall4/libnftnl/002-libnftnl-add-brcm-fullcone-support.patch > package/libs/libnftnl/patches/002-libnftnl-add-brcm-fullcone-support.patch
    sed -i '/PKG_INSTALL:=1/iPKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
    # nftables
    [ "$version" = "rc2" ] && rm -rf package/network/utils/nftables
    [ "$version" = "rc2" ] && cp -a ../master/openwrt/package/network/utils/nftables package/network/utils/nftables
    mkdir -p package/network/utils/nftables/patches
    curl -s https://$mirror/openwrt/patch/firewall4/nftables/002-nftables-add-fullcone-expression-support.patch > package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch
    [ "$TESTING_KERNEL" != "y" ] && curl -s https://$mirror/openwrt/patch/firewall4/nftables/003-nftables-add-brcm-fullconenat-support.patch > package/network/utils/nftables/patches/003-nftables-add-brcm-fullconenat-support.patch
    # hide nftables warning message
    pushd feeds/luci
        curl -s https://$mirror/openwrt/patch/luci/luci-nftables.patch | patch -p1
    popd
fi

# FullCone module
git clone https://$gitea/sbwml/nft-fullcone package/new/nft-fullcone

# IPv6 NAT
git clone https://$github/sbwml/packages_new_nat6 package/new/nat6

# natflow
git clone https://$github/sbwml/package_new_natflow package/new/natflow

# Patch Luci add nft_fullcone/bcm_fullcone & shortcut-fe & natflow & ipv6-nat & custom nft command option
pushd feeds/luci
    curl -s https://$mirror/openwrt/patch/firewall4/0001-luci-app-firewall-add-nft-fullcone-and-bcm-fullcone-.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/firewall4/0002-luci-app-firewall-add-shortcut-fe-option.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/firewall4/0003-luci-app-firewall-add-ipv6-nat-option.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/firewall4/0004-luci-add-firewall-add-custom-nft-rule-support.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/firewall4/0005-luci-app-firewall-add-natflow-offload-support.patch | patch -p1
    [ "$TESTING_KERNEL" = "y" ] && curl -s https://$mirror/openwrt/patch/firewall4/0
