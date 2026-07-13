# NuttX RK3506 AMP 移植 Patch

`nuttxos/nuttx` 是指向上游 [`apache/nuttx`](https://github.com/apache/nuttx) 的
git submodule，无法把本项目的移植 commit 直接推到上游。因此把 NuttX 侧的移植改动
以 patch 形式跟踪在这里，保证 clone 本仓库后可完整复现 CPU2 上的 NuttX。

## Patch 列表（基线：submodule 记录的 `cd6ed0dbf9`）

| Patch | 内容 |
|-------|------|
| `0001-drivers-serial-16550-add-u16550_consoledev-accessor.patch` | 16550 串口新增 `u16550_consoledev()` 访问器 |
| `0002-arch-arm-rk3506-add-Rockchip-RK3506-Cortex-A7-chip-s.patch` | RK3506（Cortex-A7）chip 层：boot/irq/serial/timer/memorymap/pgalloc |
| `0003-boards-arm-rk3506-add-Luckfox-Lyra-AMP-subsystem-boa.patch` | Luckfox Lyra AMP 板级：defconfig/链接脚本/bringup |
| `0004-boards-arm-rk3506-set-Luckfox-Lyra-AMP-NuttX-RAM-to-.patch` | NuttX RAM 设为 32MB（`CONFIG_RAM_SIZE=0x02000000`） |

## 应用方法

```bash
cd nuttxos/nuttx
# 确保 submodule 已初始化到基线
git submodule update --init .

# 应用全部移植 patch
git am ../patches/*.patch

# 配置并编译（board:config）
./tools/configure.sh -e luckfox-lyra-amp:nsh
make -j$(nproc)          # 产出 nuttx.bin
```

之后回到仓库根目录用 AMP 流程打包 + 烧录：

```bash
./build.sh lunch          # 选 rk3506b_buildroot_spinand_amp_nuttx_defconfig
./build.sh                # 大核(u-boot/kernel/rootfs) + amp(NuttX) 一起构建
```

`amp` 步骤由 `device/rockchip/common/scripts/mk-amp.sh` 的 `build_nuttx()` 驱动，
根据 `device/rockchip/rk3506/amp_nuttx.its` 的 `compile{sys="nuttx"}` 自动编译并打包。

## 内存约束（务必遵守）

- NuttX 占用：code `0x03e00000-0x03f00000`(1MB) + RAM `0x03f00000-0x05f00000`(32MB) = 33MB
- 内核 dts `amp_reserved` 必须 no-map 覆盖整段 `0x03e00000 0x2100000`
  （见 `kernel-6.1/arch/arm/boot/dts/rk3506b-luckfox-lyra-amp-spinand.dts`）
- **NuttX RAM 硬上限 193MB**（`CONFIG_RAM_SIZE ≤ 0x0C100000`）：受 rk3506 MMU 映射的
  256MB DDR 窗口（`0x00000000-0x10000000`）限制，RAM 起始 `0x03f00000`，末尾不得越过
  `0x10000000`。改 `RAM_SIZE` 时，dts 的 `amp_reserved` 长度须同步改为 `1MB + RAM_SIZE`。

## 更新 patch（改了 NuttX 源码后）

```bash
cd nuttxos/nuttx
# 在 submodule 里正常 commit 你的改动，然后重新导出：
git format-patch cd6ed0dbf9..HEAD -o ../patches --numbered
```
