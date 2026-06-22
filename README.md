[English](./README_EN.md) | **简体中文**

# ps5-unified-autoloader

一个独立的 PS5 ELF payload，用于自动加载其他 payload。本工具旨在集成到破解链中，而非直接面向最终用户使用。

## 功能说明

通过 elfldr 加载时（例如作为破解链的一部分），`autoloader.elf` 将执行以下操作：

1. **终止 YouTube**（PPSA01650/01651/01652）如果正在运行
2. **终止光盘播放器**（NPXS40140）如果正在运行，使用谨慎的 suspend→wait→kill 序列
3. **等待 elfldr** 在端口 9021 就绪（最长 10 秒）
4. **查找** `autoload.txt` 配置文件，优先级从高到低：
   - **USB 上应用专属目录**（`/mnt/usb[0-7]/ps5_autoloader_<app>/autoload.txt`，`<app>` 对于光盘播放器为 `bdjb`，对于 YouTube 则为 Title ID 如 `PPSA01650`）
   - **`/data` 下应用专属目录**（`/data/ps5_autoloader_<app>/autoload.txt`）
   - **USB 上通用目录**（`/mnt/usb[0-7]/ps5_autoloader/autoload.txt`）
   - **`/data` 下通用目录**（`/data/ps5_autoloader/autoload.txt`）
5. **如果找到配置文件**：通过 elfldr 依次加载列表中每个 payload
6. **如果未找到**：自动启动内置的 **Payload Manager**

## autoload.txt 格式

```
# 这是注释 — 会被忽略
@sync                  # 如果所有 payload 加载成功，将配置目录移动到 /data
mypayload.elf          # 从 autoload.txt 所在目录加载
anotherpayload.elf
!1000                  # 暂停 1000 毫秒再执行下一项
third_payload.elf
```

- 每行一个条目
- 文件名相对于 `autoload.txt` 所在目录解析
  （例如配置文件在 `/mnt/usb0/ps5_autoloader/autoload.txt`，则
  `mypayload.elf` 解析为 `/mnt/usb0/ps5_autoloader/mypayload.elf`）
- 绝对路径（以 `/` 开头）直接使用
- 以 `#` 开头的行为注释
- 以 `!` 开头的行为休眠命令：`!<ms>` 表示休眠指定毫秒数
- 以 `@` 开头的行为指令：
  - `@sync`：如果从 USB 驱动器加载，将所有活动配置目录（包括所有 payload 和 `autoload.txt`）移动到 PS5 内部 `/data` 分区。仅在所有 payload 成功加载且无错误时执行。它会清空目标内部目录，复制文件，逐字节校验，然后删除 USB 上的文件夹，以便后续启动无需 USB 即可从本地运行。

## 构建

### 依赖项
- Docker
- git（含 submodules，仅 `-b` 构建需要）

### 克隆
```bash
git clone https://github.com/itsPLK/ps5-unified-autoloader.git
cd ps5-unified-autoloader
```

### 构建（下载预编译 pldmgr — 推荐）
```bash
./build_release.sh
# 或显式指定：
./build_release.sh -d
```

### 构建（从源码编译 pldmgr）
```bash
git submodule update --init --recursive
./build_release.sh -b
```

此方式使用 pldmgr 自带的 Docker 镜像（包含 libmicrohttpd、mbedTLS、libcurl）
构建 pldmgr，然后使用另一个精简 SDK 镜像构建 autoloader。

### 输出
```
autoloader_v0.1.0_abc1234.elf
```

## 目录结构

```
autoloader.elf          ← 通过 elfldr 加载
  └─ pldmgr.elf         ← 内置备用 payload（未找到 autoload.txt 时启动）
```
