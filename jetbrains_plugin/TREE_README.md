<!--
SPDX-FileCopyrightText: 2025 Weibo, Inc.

SPDX-License-Identifier: Apache-2.0
-->

# WeCode IDEA 插件架构文档

本文档详细说明了 `idea/src/main/kotlin/com/sina/weibo/agent` 目录下各个模块的功能和作用。

## 项目概述

WeCode IDEA 插件是一个基于 IntelliJ 平台的扩展，它将 VSCode 的扩展机制集成到 IDEA 中，使得基于 VSCode API 开发的扩展能够在 IDEA 环境中运行。

## 目录结构说明

### 📁 `actions/` - 动作管理模块
**作用**: 处理用户交互和IDEA中的代码操作

- **核心功能**:
  - 注册和管理右键菜单操作
  - 处理代码相关的用户操作（解释、修复、改进等）
  - 集成IDEA的Action系统

- **主要文件**:
  - [`RegisterCodeActions.kt`](src/main/kotlin/com/sina/weibo/agent/actions/RegisterCodeActions.kt): 注册代码操作
  - [`RightClickChatActionGroup.kt`](src/main/kotlin/com/sina/weibo/agent/actions/RightClickChatActionGroup.kt): 右键菜单组
  - [`VSCodeCommandActions.kt`](src/main/kotlin/com/sina/weibo/agent/actions/VSCodeCommandActions.kt): VSCode命令操作

### 📁 `actors/` - 主线程服务实现
**作用**: 实现VSCode扩展API的主线程服务

- **核心功能**:
  - 提供VSCode扩展API的IDEA实现
  - 处理UI相关的操作（必须在主线程执行）
  - 管理扩展与IDEA的交互

- **主要服务**:
  - `MainThreadDiaglogsShape`: 文件对话框服务
  - `MainThreadFileSystemShape`: 文件系统操作
  - `MainThreadLanguageFeaturesShape`: 语言特性支持
  - `MainThreadExtensionServiceShape`: 扩展管理服务
  - `MainThreadMessageServiceShape`: 消息服务
  - `MainThreadConfigurationShape`: 配置管理
  - `MainThreadDebugServiceShape`: 调试服务
  - `MainThreadLanguageModelToolsShape`: AI工具服务

### 📁 `commands/` - 命令定义
**作用**: 定义和管理VSCode命令

- **核心功能**:
  - 定义可用的命令标识符
  - 管理命令到实际功能的映射

- **主要文件**:
  - [`Commands.kt`](src/main/kotlin/com/sina/weibo/agent/commands/Commands.kt): 命令定义

### 📁 `core/` - 核心管理模块
**作用**: 插件的核心管理和协调

- **核心功能**:
  - 扩展生命周期管理
  - 进程间通信管理
  - Socket服务器管理
  - 服务代理注册

- **主要组件**:
  - [`ExtensionManager.kt`](src/main/kotlin/com/sina/weibo/agent/core/ExtensionManager.kt): 扩展管理器
  - [`ExtensionProcessManager.kt`](src/main/kotlin/com/sina/weibo/agent/core/ExtensionProcessManager.kt): 扩展进程管理
  - [`ExtensionSocketServer.kt`](src/main/kotlin/com/sina/weibo/agent/core/ExtensionSocketServer.kt): Socket服务器
  - [`ServiceProxyRegistry.kt`](src/main/kotlin/com/sina/weibo/agent/core/ServiceProxyRegistry.kt): 服务代理注册表
  - [`RPCManager.kt`](src/main/kotlin/com/sina/weibo/agent/core/RPCManager.kt): RPC管理器

### 📁 `editor/` - 编辑器集成
**作用**: IDEA编辑器与VSCode扩展的集成

- **核心功能**:
  - 管理编辑器状态
  - 处理文档同步
  - 管理标签页状态
  - 处理编辑器事件

- **主要组件**:
  - [`EditorAndDocManager.kt`](src/main/kotlin/com/sina/weibo/agent/editor/EditorAndDocManager.kt): 编辑器和文档管理
  - [`EditorStateService.kt`](src/main/kotlin/com/sina/weibo/agent/editor/EditorStateService.kt): 编辑器状态服务
  - [`TabStateManager.kt`](src/main/kotlin/com/sina/weibo/agent/editor/TabStateManager.kt): 标签状态管理

### 📁 `events/` - 事件系统
**作用**: 事件总线和事件处理

- **核心功能**:
  - 管理应用内事件
  - 处理WebView事件
  - 工作区事件管理

- **主要文件**:
  - [`EventBus.kt`](src/main/kotlin/com/sina/weibo/agent/events/EventBus.kt): 事件总线
  - [`WebviewEvents.kt`](src/main/kotlin/com/sina/weibo/agent/events/WebviewEvents.kt): WebView事件
  - [`WorkspaceEvents.kt`](src/main/kotlin/com/sina/weibo/agent/events/WorkspaceEvents.kt): 工作区事件

### 📁 `ipc/` - 进程间通信
**作用**: 处理IDEA与扩展进程之间的通信

- **核心功能**:
  - 消息协议实现
  - Socket通信
  - 数据序列化/反序列化
  - RPC代理实现

- **主要组件**:
  - [`IMessagePassingProtocol.kt`](src/main/kotlin/com/sina/weibo/agent/ipc/IMessagePassingProtocol.kt): 消息传递协议接口
  - [`ProtocolMessage.kt`](src/main/kotlin/com/sina/weibo/agent/ipc/ProtocolMessage.kt): 协议消息定义
  - [`NodeSocket.kt`](src/main/kotlin/com/sina/weibo/agent/ipc/NodeSocket.kt): Node.js Socket实现
  - [`PersistentProtocol.kt`](src/main/kotlin/com/sina/weibo/agent/ipc/PersistentProtocol.kt): 持久化协议

#### 📁 `ipc/proxy/` - RPC代理实现
- **RPCProtocol.kt**: 核心RPC协议实现
- **ProxyIdentifier.kt**: 代理标识符
- **MessageIO.kt**: 消息IO处理
- **接口定义**: 各种ExtHost代理接口

### 📁 `model/` - 数据模型
**作用**: 定义数据结构

- **主要文件**:
  - [`WorkspaceData.kt`](src/main/kotlin/com/sina/weibo/agent/model/WorkspaceData.kt): 工作区数据模型

### 📁 `plugin/` - 插件入口
**作用**: 插件的主入口和生命周期管理

- **核心功能**:
  - 插件初始化
  - 服务管理
  - 生命周期控制

- **主要文件**:
  - [`WecoderPlugin.kt`](src/main/kotlin/com/sina/weibo/agent/plugin/WecoderPlugin.kt): 插件主类
  - [`SystemObjectProvider.kt`](src/main/kotlin/com/sina/weibo/agent/plugin/SystemObjectProvider.kt): 系统对象提供器

### 📁 `service/` - 服务层
**作用**: 提供各种业务服务

- **主要服务**:
  - [`DocumentSyncService.kt`](src/main/kotlin/com/sina/weibo/agent/service/DocumentSyncService.kt): 文档同步服务
  - [`ExtensionStorageService.kt`](src/main/kotlin/com/sina/weibo/agent/service/ExtensionStorageService.kt): 扩展存储服务

### 📁 `terminal/` - 终端集成
**作用**: 终端功能集成

- **主要组件**:
  - [`TerminalInstance.kt`](src/main/kotlin/com/sina/weibo/agent/terminal/TerminalInstance.kt): 终端实例
  - [`TerminalInstanceManager.kt`](src/main/kotlin/com/sina/weibo/agent/terminal/TerminalInstanceManager.kt): 终端管理器
  - [`TerminalShellIntegration.kt`](src/main/kotlin/com/sina/weibo/agent/terminal/TerminalShellIntegration.kt): Shell集成

### 📁 `theme/` - 主题管理
**作用**: 主题和样式管理

- **主要文件**:
  - [`ThemeManager.kt`](src/main/kotlin/com/sina/weibo/agent/theme/ThemeManager.kt): 主题管理器

### 📁 `ui/` - UI组件
**作用**: 用户界面组件

- **主要文件**:
  - [`RooToolWindowFactory.kt`](src/main/kotlin/com/sina/weibo/agent/ui/RooToolWindowFactory.kt): 工具窗口工厂

### 📁 `util/` - 工具类
**作用**: 通用工具类和辅助功能

- **主要工具**:
  - [`ExtensionUtils.kt`](src/main/kotlin/com/sina/weibo/agent/util/ExtensionUtils.kt): 扩展工具类
  - [`URIUtil.kt`](src/main/kotlin/com/sina/weibo/agent/util/URIUtil.kt): URI工具类
  - [`NotificationUtil.kt`](src/main/kotlin/com/sina/weibo/agent/util/NotificationUtil.kt): 通知工具类
  - [`PluginConstants.kt`](src/main/kotlin/com/sina/weibo/agent/util/PluginConstants.kt): 插件常量

### 📁 `webview/` - WebView集成
**作用**: WebView组件管理

- **主要组件**:
  - [`WebViewManager.kt`](src/main/kotlin/com/sina/weibo/agent/webview/WebViewManager.kt): WebView管理器
  - [`LocalResHandler.kt`](src/main/kotlin/com/sina/weibo/agent/webview/LocalResHandler.kt): 本地资源处理器

### 📁 `workspace/` - 工作区管理
**作用**: 工作区相关功能

- **主要组件**:
  - [`WorkspaceFileChangeManager.kt`](src/main/kotlin/com/sina/weibo/agent/workspace/WorkspaceFileChangeManager.kt): 文件变更管理器

## 架构流程

1. **启动流程**:
   - `WecoderPlugin.kt` → 初始化插件
   - 启动Socket服务器
   - 启动扩展进程
   - 注册服务代理

2. **通信流程**:
   - IDEA ↔ Socket ↔ 扩展进程
   - 使用RPC协议进行通信
   - 通过代理模式调用远程方法

3. **功能集成**:
   - VSCode扩展API → IDEA实现
   - 事件系统协调各组件
   - WebView提供UI界面

## 调试模式

插件支持三种调试模式：
- **ALL**: 全部调试模式
- **IDEA**: 仅IDEA插件调试
- **NONE**: 不启用调试

调试配置通过 `plugin.properties` 文件进行设置。

## 技术栈

- **语言**: Kotlin
- **平台**: IntelliJ Platform
- **通信**: Socket/Unix Domain Socket
- **协议**: 自定义RPC协议
- **UI**: JavaFX/Swing + WebView
- **构建**: Gradle
