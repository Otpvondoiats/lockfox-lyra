# 从零构建并刷机（RK3506 Luckfox Lyra AMP：Linux + NuttX 双核）

本仓库自带离线构建所需的一切：buildroot 下载缓存（`buildroot/dl`，超 100MB 的
文件已分卷）、NuttX RK3506 移植 patch（`nuttxos/patches`）、AMP 打包脚本。
clone 后一条命令即可构建，无需联网下载源码包。

## 一键构建

```bash
git clone <this-repo> lockfox-lyra
cd lockfox-lyra
./tools/setup-and-build.sh
```

该脚本依次完成：

1. `git submodule update --init nuttxos/nuttx nuttxos/nuttx-apps`
2. `git am nuttxos/patches/*.patch`（应用 NuttX RK3506 CPU2 移植）
3. `tools/restore-dl-splits.sh`（把 `buildroot/dl` 里的分卷重组还原，sha256 校验）
4. `./build.sh rk3506b_buildroot_spinand_amp_nuttx_defconfig`（选板）
5. `./build.sh`（编 u-boot + kernel + rootfs + NuttX amp 并打包）

产物在 `output/firmware/`：`MiniLoaderAll.bin` / `uboot.img` / `boot.img` /
`rootfs.img` / `parameter.txt`，以及 amp 分区镜像 `output/firmware/amp.img`
（内含 CPU2 的 NuttX）。

## 手动分步（等价于上面的脚本）

```bash
git submodule update --init nuttxos/nuttx nuttxos/nuttx-apps
( cd nuttxos/nuttx && git am ../patches/*.patch )
./tools/restore-dl-splits.sh
./build.sh rk3506b_buildroot_spinand_amp_nuttx_defconfig
./build.sh
```

## 刷机（整片，SPI NAND）

板子进 Loader/Maskrom 模式后（断电 → 按住 BOOT 键上电）：

```bash
UT=./rkbin/tools/upgrade_tool
FW=output/firmware
$UT ld                                  # 确认 Mode=Loader
$UT di -p     $FW/parameter.txt
$UT di -uboot $FW/uboot.img
$UT di -boot  $FW/boot.img
$UT EL 0x12000 0x6DB00                   # ★先整片擦 rootfs 分区(UBI坑)
$UT di -rootfs $FW/rootfs.img
$UT wl 0x10000 $FW/amp.img               # NuttX 到 amp 分区
$UT rd                                   # 重启
```

> ⚠️ **刷 rootfs（UBI 卷）前必须先 `EL` 整片擦除该分区**，否则尾部残留旧 UBI
> PEB 的 `image_seq` 冲突会导致大核 `Unable to mount root fs` panic。
> 只刷 amp 分区（raw FIT）不受此影响，`wl 0x10000` 整块覆盖即可。

分区偏移（见 `parameter-lyra-spinand-amp.txt`）：
uboot@0x2000, boot@0x4000, amp@0x10000, rootfs@0x12000。

## 串口

- `/dev/ttyACM4`（by-path 12.1）= NuttX（CPU2，UART4 @1500000）
- `/dev/ttyACM5`（by-path 12.2）= Linux（console=ttyFIQ0 @1500000）

## NuttX 内存约束

- 占用：code `0x03e00000-0x03f00000`(1MB) + RAM `0x03f00000-0x05f00000`(32MB) = 33MB
- 内核 dts `amp_reserved` 已 no-map 覆盖整段 `0x03e00000 0x2100000`
- **RAM 硬上限 193MB**（`CONFIG_RAM_SIZE ≤ 0x0C100000`）：受 rk3506 MMU 映射的
  256MB DDR 窗口限制。改 `RAM_SIZE` 时须同步更新 dts 的 `amp_reserved` 长度
  （= 1MB + RAM_SIZE），详见 `nuttxos/patches/README.md`。

## 关于 buildroot/dl 分卷

GitHub 单文件上限 100MB。`buildroot/dl` 中超限的文件（当前仅
`rust-1.74.1-x86_64-unknown-linux-gnu.tar.xz`，149MB）以字节精确的裸分卷存储：

- `<name>.part-00`, `<name>.part-01`, ...（每卷 80MB）
- `<name>.sha256`（原文件 sha256 + 文件名）

`tools/restore-dl-splits.sh` 用 `cat` 重组并校验 sha256，还原字节完全一致，
所以 buildroot 自身的包哈希校验会通过、不会触发重新下载。
