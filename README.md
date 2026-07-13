# 产品介绍

官方 url：https://wiki.luckfox.com/zh/Luckfox-Lyra/Introduction
这个是官方的sdk解压文件，原sdk：https://wiki.luckfox.com/zh/Luckfox-Lyra/Download

1. 介绍
Luckfox Lyra 系列主控采用 Rockchip RK3506G2/RK3506B 处理器，该处理器采用 22nm 制程工艺，搭载了4 核 32 位 CPU（包括 3×Cortex-A7 和 1×Cortex-M0），丰富的接口扩展，适用于多种应用领域，包括物联网设备、智能音频、智能显示、工业控制和教育设备等。Luckfox Lyra 支持 Buildroot 系统。


# 构建

～～～
git clone <repo> && cd lockfox-lyra
git submodule update --init nuttxos/nuttx nuttxos/nuttx-apps
( cd nuttxos/nuttx && git am ../patches/*.patch )   # 手动打 NuttX patch
./tools/restore-dl-splits.sh                         # 还原被分卷的 dl(sha256 校验)
./build.sh rk3506b_buildroot_spinand_amp_nuttx_defconfig
./build.sh                                           # 大小核 image 一起出

～～～
