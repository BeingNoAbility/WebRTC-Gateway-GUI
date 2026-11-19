# WebRTC Gateway Manager (GUI)

> 基于 Flutter 的现代跨平台图形用户界面（GUI），统一覆盖 **Windows 桌面端** 与 **Android 移动端**，专为 [WebRTC-Gateway](https://github.com/BeingNoAbility/WebRTC-Gateway) 内网穿透网关打造。

---

## 🌟 核心特性与设计亮点

### 1. 统一风格设计 (Unified Material 3)
- **跨端一致视觉**：Windows 与 Android 采用统一的现代化 Cyber Slate 调色板与 Material 3 设计语言，支持**暗黑模式 (Dark)** 与 **明亮模式 (Light)** 一键无缝切换。
- **响应式自适应布局**：
  - 🖥️ **桌面/宽屏端（>= 800px）**：左侧扩展 `NavigationRail` 导航栏、多列仪表盘流、实时 HUD 数据卡片。
  - 📱 **移动端/手机屏（< 800px）**：底部磨砂浮动 `NavigationBar`、触控优化大卡片、单手手势流。采用弹性 `LayoutBuilder` 与 `Wrap` 双层流式排版，已彻底解决各种超窄/异形屏（如 360px ~ 420px 手机竖屏）上的横向溢出问题。
- **🖥️ Windows 系统托盘常驻 (System Tray & Minimization)**：
  - 支持关闭窗口时平滑最小化至 Windows 任务栏通知区（系统托盘小图标），确保穿透 Agent 持续在后台静默运行。
  - 托盘右键菜单支持：显示主面板、一键拉起/停止全部 Agent 穿透集群、彻底退出程序。
  - 可以在「配置设置」中随时开启或关闭“最小化到托盘”功能。

### 1. 多 Agent 集群并发管理 (Multi-Agent Cluster Hub)
- **多实例同时运行**：完全支持在同一台机器上并发启动、停止和管理多个独立的 WebRTC Agent 实例。
- **动态端口防冲突分配**：每个 Agent 自动分配独立的 Prometheus Metrics 端口（如 `:9091`, `:9092`, `:9093` 等），彻底杜绝端口冲突。
- **集群全局 HUD 仪表盘**：顶栏实时聚合展示整个集群的总活跃对等连接数（Peers）、全集群实时下行/上行总吞吐速率以及累计数据量。
- **卡片化多实例管控**：
  - 支持“新建 Agent”模态框，为不同穿透场景分配独立名称与专属 Node ID。
  - 一键“全部启动”与“全部停止”集群批量操作。
  - 每个 Agent 实例拥有独立的启动/停止控制、开机自启开关、配置抽屉、安全分享弹窗与独立日志流。
- **三大穿透模式自由搭配**：
  - 🔄 **Web应用反代**：HTTP/WebSocket 本地或局域网服务穿透（如 `http://127.0.0.1:8080`）。
  - 📁 **本地目录托管**：本地文件夹只读浏览与极速下载。
  - 📄 **单文件极速分发**：零端口监听直连分发大文件（ISO、视频、安装包）。
- **安全分享弹窗**：内置纯数学 HMAC-SHA256 时效签名算法，生成 1小时 / 24小时 / 7天 / 30天限时直连链接并生成二维码，支持一键复制与系统浏览器直达。

2. **🌐 访客连接中心 (Visitor Hub)**
   - 快速连接栏：支持直接粘贴分享链接（自动解析 URL Hash 片段与签名参数）或手动输入 Node ID + 门户地址。
   - **常用节点收藏夹 (Bookmarks)**：保存常用 NAS、办公室 PC、开发机等节点，显示最后访问时间，一键打开。

3. **📡 信令服务端管理 (Signal Server Host)**
   - 本地信令服务一键开关（默认 `:8888` 端口）。
   - Anti-CSWSH 跨域白名单策略配置、允许全部跨域开关。
   - 一键生成内存自签 HTTPS 证书（`-tls-auto`），为局域网激活 Service Worker Secure Context 安全上下文。
   - 实时监控在线注册 Agent 节点数与连接数。

4. **⚡ 网络与穿透诊断工具箱 (Diagnostics Toolkit)**
   - **一键全景网络穿透体检**：
     - 本地目标 Web 服务端口连通性与 HTTP 探活。
     - 信令服务器 WebSocket 端口可用性探测。
     - 国际标准 RFC 5389 UDP 探测包，实时测试 Google STUN / Cloudflare STUN 往返延迟（RTT）。
   - 单点 STUN/TURN 自定义测试工具。

5. **📜 实时运行日志 (Interactive Terminal Logs)**
   - 赛博黑客风格终端控制台，支持自动滚动锁定与切换。
   - 按级别筛选（全部、信息、警告、错误、成功）与关键字即时搜索。
   - 一键清空与复制完整日志。

6. **⚙️ 系统与高级设置 (Settings & Profiles)**
   - 主题外观切换（暗黑 / 明亮 / 跟随系统）。
   - Windows 自定义 Go 核心二进制路径覆盖（`agent.exe` / `signal.exe`）。
   - **官方 YAML 配置文件双向互通**：查看、复制导出 `agent.yaml`，或导入外部 YAML 规则。

---

## 📁 目录结构

```text
WebRTC-Gateway-GUI/
├── lib/
│   ├── main.dart                  # 应用统一入口、MultiProvider 与主题挂载
│   ├── core/
│   │   ├── constants/             # 统一色彩 AppColors、默认常量 AppConstants
│   │   ├── models/                # AgentConfig、SignalConfig、AgentMetrics、LogEntry、RemoteNode
│   │   ├── theme/                 # Material 3 浅色与深色主题定义
│   │   └── utils/                 # HMAC-SHA256 签名器、网络诊断器、多进程管控器
│   ├── providers/                 # AgentProvider, SignalProvider, VisitorProvider, DiagnosticsProvider, SettingsProvider
│   ├── services/                  # Agent 进程管理与指标轮询、信令服务端管控、持久化存储
│   └── ui/
│       ├── screens/               # 穿透端、访客中心、信令端、诊断箱、日志台、设置页
│       └── widgets/               # 状态徽章、HUD卡片、二维码分享框、模式选择器、终端日志视图
├── assets/
│   └── bin/                       # Windows 预置预编译 Go 核心二进制 (agent.exe, signal.exe)
├── android/                       # Android 工程配置 (网络权限、清爽文本通信配置)
├── windows/                       # Windows Desktop 工程配置 (C++ Runner, 窗口尺寸与标题定制)
└── test/                          # 自动化单元测试 (HMAC算法跨端验证、Prometheus指标解析、CLI参数生成)
```

---

## 🚀 运行与构建

### 1. 运行桌面端 (Windows)
```bash
flutter run -d windows
```

### 2. 运行移动端 (Android)
```bash
flutter run -d android
```

### 3. 构建与分发形态

#### 💻 方案 A：绿色单文件免安装版 (Zero-Dependency Standalone .exe)
本项目提供专用的单文件打包工具，将 Flutter Release 核心、依赖 DLL、运行时资源与 Go 原生内核（`agent.exe`, `signal.exe`）100% 打包为单一便携可执行文件：
```bash
# 1. 编译 Flutter Windows Release 目录
flutter build windows --release

# 2. 执行一键单文件自解压打包器（自动注入 PE 清单、图标与数字签名）
go run tools/standalone_packer/main.go
```
- **产物位置**：`WebRTC-Gateway-Manager-Standalone.exe` (约 49.8 MB)
- **纯粹单文件**：单一 `.exe`，双击即用，无需配置环境或手动解压。
- **官方 Cyber Shield 图标**：已内嵌官方多尺寸矢量图标（`.ico`）及应用清单（GUI Manifest）。若下载到曾经存放过同名老文件的目录，Windows 资源管理器可能存在图标缓存，只需将文件更名、移到新目录或重启 Explorer 即可即时看到官方盾牌图标。
- **无黑框秒开**：原生 Windows GUI 子系统调起，首次自动无感挂载运行时至 `%LOCALAPPDATA%`。

#### 📦 方案 B：便携免解压绿色包 (Portable Green Zip - 杀软 100% 零误报)
针对严苛企业机房、受限域控电脑或对“单文件运行时释放”敏感的高敏感杀软环境，推荐直接使用绿色免安装包：
- **产物位置**：`WebRTC-Gateway-Manager-v2.3.2-windows-x64-green.zip` (约 48.2 MB)
- **零释放器行为**：解压即可运行 `webrtc_gateway_gui.exe`，完全由操作系统动态链接器标准加载 DLL，**天生杜绝所有 Dropper 释放木马启发式误报**。

#### 🛡️ Windows 端防杀软误报与数字签名方案
1. **注入完整 PE 资源**：通过 `go-winres` 注入官方应用程序清单（GUI Manifest）、版本号（2.3.2.0）及版权元数据，消除“未知无资源可执行程序”的高风险判定。
2. **本地证书一键信任**：运行 `powershell -ExecutionPolicy Bypass -File tools/trust_cert.ps1`，自动将代码签名证书加入当前用户的受信任发布者库，彻底消除 Windows Defender / SmartScreen 拦截。
3. **官方云端误报申报**：若部署在企业环境，可通过微软 [WDSI 误报提交通道](https://www.microsoft.com/en-us/wdsi/filesubmission) 提交白名单洗白。

#### 📱 Android APK 安装包
```bash
flutter build apk --release
# 产物位于: build/app/outputs/flutter-apk/app-release.apk (测试版在 app-debug.apk)
```

---

## 🛡️ 安全合规与架构规范
- **端到端加密传输**：遵循 RFC 8831 规范，WebRTC RTCDataChannel 建立在 DTLS 1.2 / SRTP 传输层加密之上，控制面与数据面秘钥物理隔离。
- **无状态时效签名**：纯数学 HMAC-SHA256 签名，避免中间人篡改或恶意探测。
