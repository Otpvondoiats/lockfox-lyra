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
4. `./build.sh chip:rk3506:rk3506b_buildroot_spinand_amp_nuttx_defconfig`（选板）
5. `./build.sh`（编 u-boot + kernel + rootfs + NuttX amp 并打包）

> 注意第 4 步必须用 `chip:rk3506:<defconfig>` 形式，不能只写 `<defconfig>`。
> 全新 clone 时 `device/rockchip/.chip` 符号链接还不存在（它被 gitignore、
> 由首次选型时创建），直接 `./build.sh <defconfig>` 会因找不到 `.chip` 而报
> `No available defconfigs`。`chip:` 形式会先创建 `.chip` 再选 defconfig。

产物在 `output/firmware/`：`MiniLoaderAll.bin` / `uboot.img` / `boot.img` /
`rootfs.img` / `parameter.txt`，以及 amp 分区镜像 `output/firmware/amp.img`
（内含 CPU2 的 NuttX）。

## 手动分步（等价于上面的脚本）

```bash
git submodule update --init nuttxos/nuttx nuttxos/nuttx-apps
( cd nuttxos/nuttx && git am ../patches/*.patch )
./tools/restore-dl-splits.sh
./build.sh chip:rk3506:rk3506b_buildroot_spinand_amp_nuttx_defconfig
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

## 全新 clone 端到端验证记录（2026-07-13）

在空目录里 `git clone` → 按上面流程走了一遍，发现并修复了 4 个可复现性问题，
最终**完整构建出双核 image 并验证通过**：

| # | 现象 | 根因 | 修复 |
|---|------|------|------|
| 1 | `./build.sh <defconfig>` 报 `No available defconfigs` | 全新 clone 无 `device/rockchip/.chip` 符号链接（gitignore，首次选型时才建），`switch_defconfig` 进不去 | 文档/脚本改用 `./build.sh chip:rk3506:<defconfig>`（先建 `.chip` 再选） |
| 2 | rootfs 构建失败：`ifupdown-scripts/network` 目录缺失 | 见 #3 | 随 #3 一并修复 |
| 3 | 根 `.gitignore` 的 `*.d` / `*.cmd` / `*.ko` 全局规则误伤 buildroot **源码**（`if-up.d`/`init.d`/`rules.d`/`weston.ini.d` 等 77 个文件，含关键的 `package/initscripts/init.d/rcS`、`rcK`），import 时就没进 git | `git add -f` 强制纳入这 77 个文件（已跟踪文件不再受 gitignore 影响；未改宽泛规则以免误收构建产物） |
| 4 | rootfs 构建失败：`rkadk_version.h:24: fatal error: version.h: No such file` | `app/rkadk` 是嵌套 git 仓库，`include/version.h` 由构建时 `git describe` 生成；SDK 导入主仓库时嵌套 `.git` 未带过来，clone 后无从生成 | 把生成好的 `version.h` 作为种子文件 vendored 进仓库（`git add -f`） |

**最终验证结果**：修复 #1~#4 后，全新 clone 端到端跑通全部环节：
clone / submodule init / `git am`（4 patch）/ dl 分卷还原（sha256 通过）/
u-boot / kernel（33MB `amp_reserved` dtb 生效）/ rootfs（buildroot 离线）/
**NuttX amp（`build_nuttx` 打包，`amp.img` 内含 `NuttShell (NSH) NuttX-13.0.0`）**。
产物齐全：`output/firmware/` 下 `MiniLoaderAll.bin` / `uboot.img` / `boot.img` /
`rootfs.img`(117MB) / `amp.img`(NuttX) / `parameter.txt` / `update.img`(128MB)。

> 排错提示：`./build.sh 2>&1 | tee log | tail` 外层 `rc=0` 是 `tee` 的退出码，
> **不代表构建成功**。判断成败看 `output/firmware/` 是否齐全，或 grep
> `Failed to build` / `build_all succeeded`。另外改了 local 包（如 rkadk）的源码后，
> 需删 `buildroot/output/*/build/<pkg>/` 强制重新 rsync，只删 `.stamp_built` 不够。
