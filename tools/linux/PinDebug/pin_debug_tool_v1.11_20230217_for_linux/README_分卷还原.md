# pin_debug_tool 分卷说明

原始文件 `pin_debug_tool`（约 157MB）超过 GitHub 100MB 单文件硬限制，
已用 zip 分卷压缩为每卷 80MB 存入仓库：

- `pin_debug_tool.zip`  (第 1 卷)
- `pin_debug_tool.z01`  (第 2 卷)

## 还原为可执行文件

在本目录下执行（需保证 `.zip` 和 `.z01` 都在）：

```bash
# 1. 合并分卷为单个 zip
zip -s 0 pin_debug_tool.zip --out pin_debug_tool_full.zip

# 2. 解压得到二进制
unzip pin_debug_tool_full.zip

# 3. 赋予可执行权限
chmod +x pin_debug_tool

# 4. 清理临时文件（可选）
rm -f pin_debug_tool_full.zip
```

> 原始 SDK 来源：Luckfox Lyra SDK (Luckfox_Lyra_SDK_250815)，
> 原打包文件为 `pin_debug_tool_v1.11_for_linux.tar`。
