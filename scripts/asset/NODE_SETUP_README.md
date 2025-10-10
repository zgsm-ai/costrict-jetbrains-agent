# Node.js 环境检测和安装工具

本工具用于检测系统中的 Node.js 环境，并在必要时安装内置的 Node.js 20.6.0 版本。

## 功能特性

1. **自动检测 Node.js 环境**

   - 检测系统是否已安装 Node.js
   - 如果未安装，自动安装内置的 Node.js 20.6.0

2. **版本检查**

   - 如果已安装 Node.js，会检查版本
   - 版本 < 20.6.0：提示用户升级
   - 版本 ≥ 20.6.0：提示可以继续

3. **自动配置环境变量** 🆕

   - 安装完成后**自动添加**到 PATH 环境变量（无需手动确认）
   - Linux/macOS：自动识别 shell 类型（bash/zsh/fish）并修改相应配置文件
   - Windows：使用 setx 命令永久修改用户环境变量
   - 当前会话立即生效，可以直接使用 node 命令
   - 智能检测，避免重复添加

4. **跨平台支持**
   - Linux (x64)
   - macOS (x64 和 ARM64)
   - Windows (x64)

## 使用方法

### Linux / macOS

```bash
# 进入 distributions 目录
cd /path/to/distributions

# 运行脚本
./setup-node.sh
```

### Windows

```batch
# 进入 distributions 目录
cd \path\to\distributions

# 运行脚本
setup-node.bat
```

或者直接双击 `setup-node.bat` 文件。

## 环境变量设置

### 自动配置（默认行为）

脚本会在安装完成后**自动添加**到 PATH 环境变量，无需任何手动操作：

- **Linux/macOS**: 自动识别您使用的 shell（bash/zsh/fish），并添加到对应的配置文件
- **Windows**: 使用 `setx` 命令永久修改用户环境变量
- **当前会话**: 立即生效，可以直接使用 `node` 命令
- **新会话**: 重新打开终端或运行 `source` 命令即可

**✨ 完全自动化，开箱即用！**

### 手动配置（参考）

如果您想在其他系统或场景中手动配置 PATH，可以参考以下方法：

#### Linux / macOS (临时)

```bash
export PATH="$HOME/.local/share/nodejs/bin:$PATH"
```

#### Linux / macOS (永久)

根据您使用的 shell，添加到对应的配置文件：

```bash
# Bash
echo 'export PATH="$HOME/.local/share/nodejs/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.local/share/nodejs/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Fish
echo 'set -gx PATH "$HOME/.local/share/nodejs/bin" $PATH' >> ~/.config/fish/config.fish
```

#### Windows (手动)

```batch
# 永久设置（推荐）
setx PATH "%LOCALAPPDATA%\nodejs;%PATH%"

# 或者通过图形界面：
# 1. 右键 "此电脑" → "属性"
# 2. 点击 "高级系统设置"
# 3. 点击 "环境变量"
# 4. 在用户变量中找到 "Path"，点击 "编辑"
# 5. 添加 %LOCALAPPDATA%\nodejs
```

## 目录结构

### 安装目录（脚本运行后自动创建）

**Windows**: `%LOCALAPPDATA%\nodejs\`

```
C:\Users\<username>\AppData\Local\nodejs\
├── node.exe
├── npm.cmd
└── ... (其他 Node.js 文件)
```

**Linux/macOS**: `~/.local/share/nodejs/`

```
~/.local/share/nodejs/
├── bin/
│   ├── node
│   ├── npm
│   └── npx
└── ... (其他 Node.js 文件)
```

## 故障排除

**Windows 解决方案：**

- 确保 PowerShell 可用（Windows 7+ 自带）

### 问题：权限不足（Linux/macOS）

**解决方案：**

```bash
chmod +x setup-node.sh
```

## 安装位置

内置的 Node.js 会安装到用户目录下，不会污染系统目录：

- **Windows**: `%LOCALAPPDATA%\nodejs` (通常是 `C:\Users\<username>\AppData\Local\nodejs`)
- **Linux/macOS**: `~/.local/share/nodejs`

这些是标准的用户级应用程序安装位置，卸载时只需删除对应目录即可。

## 注意事项

1. 内置的 Node.js 版本为 20.6.0，这是推荐的最低版本
2. 如果系统已安装更高版本的 Node.js，脚本不会覆盖系统安装
3. 内置的 Node.js 安装到用户目录，不需要管理员权限
4. **脚本会自动配置 PATH 环境变量**，无需任何手动操作
5. 自动配置的 PATH 会立即在当前会话生效，新终端会话需要重新打开
6. 脚本会智能检测，避免重复添加相同的 PATH 路径
7. 卸载时只需删除安装目录，并从 PATH 中移除对应路径

## 版本要求

- **最低版本：** 20.6.0
- **推荐版本：** 20.6.0 或更高

---

如有问题或建议，请联系开发团队。
