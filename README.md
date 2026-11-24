# WebRTC Gateway Desktop GUI

<p align="center">
  <img src="assets/images/logo-banner.svg" alt="WebRTC Gateway Banner" width="820">
</p>

### 现代化跨平台 WebRTC 零客户端 P2P 内网穿透桌面客户端 (Windows 优先)
A modern cross-platform desktop GUI for **[WebRTC-Gateway](https://github.com/BeingNoAbility/WebRTC-Gateway)** built with Flutter & Dart.

---

## 🌟 核心特性 (Key Features)

- **多 Agent 实例并发管理 (Multi-Agent Concurrent Pool)**：支持同时配置并运行多个独立的穿透节点，内部自动动态调度 Prometheus 端口（如 `:9091`, `:9092`...），彻底消除多实例端口冲突。
- **开箱即用与灵活核心管理 (Battery-Included & Custom Binaries)**：
  - GitHub CI 自动化拉取上游 `BeingNoAbility/WebRTC-Gateway` 最新 Release 并搭载对应系统平台的二进制文件（Windows 下解压即可直接穿透，无需手动配置 Go 环境）。
  - 支持在设置中点选本地任意第三方或自编译 `agent.exe`，自动执行 `-help` 探测并回显版本号。
- **开箱即用三模全场景穿透 (Multi-Mode)**：
  - **本地服务反代 (`-target`)**：内置 Ollama (`11434`)、ComfyUI (`8188`)、Jellyfin (`8096`)、群晖 NAS (`5000`) 等常用本地应用端口预设。
  - **静态目录托管 (`-dir`)**：点选文件夹，一键通过 P2P 共享整个目录。
  - **单文件高速直传 (`-file`)**：点选大文件，生成点对点流式下载通道。
- **Multi-PC 物理链路聚合 (Trunking Slider)**：直观滑动条（1~8 路），充分释放多核 CPU 算力，突破 Chromium 单核 SCTP 吞吐瓶颈。
- **极客观测仪与流级强杀 (HUD 2.0 & Stream Control)**：
  - 实时绘制聚合/单节点上下行网速（KB/s、MB/s）与活跃流曲线。
  - 实时列出活跃数据流，遇到卡死或大文件传输时支持一键 `RST_STREAM` 强行重置。
- **极速分享与访客免客户端直连 (Quick Share)**：
  - 自动生成 Web 直连访问 URL（`https://signal.domain/#node-id`）。
  - 动态渲染移动端扫码直连二维码。
  - 支持配置有效时长的 HMAC-SHA256 签名安全分享链接。
  - **一键复制格式化分享卡片**：优雅格式排版，一键粘贴至微信/QQ/钉钉。
- **网络诊断与打洞连通性优化 (Diagnostics)**：
  - **NAT 类型诊断 (RFC 3489)**：探测 Full Cone、Restricted Cone、Symmetric NAT (NAT 4)，提前获知 P2P 穿透潜力。
  - **公共 STUN 低延迟测速**：内置 Google、Cloudflare、腾讯、小米等优质 STUN 列表，异步 Ping 延迟并排重排序。
- **本地信令服务端管理 (Local Signal Manager)**：
  - GUI 内一键开启本地内置 `signal.exe`（支持一键 `-tls-auto` 自签证书），专为无公网局域网测试与私有信令部署打造。
- **Windows 桌面深度融合 (Desktop Integration)**：
  - 系统托盘常驻，支持关闭最小化至托盘与托盘右键快捷菜单。
  - **网络变更原地自愈 (Network Auto-Heal)**：监听笔记本休眠唤醒、Wi-Fi 切换与断线重连，自动触发 Agent 原地自愈。
- **配置全量备份与双语国际化 (Backup & Zero-Dep i18n)**：
  - 一键导出/导入所有节点配置为 `.json` 文件。
  - 简体中文与 English 原地无感热切换。

---

## 🏗️ 架构与目录规范 (Project Structure)

```text
WebRTC-Gateway-GUI/
├── assets/                         # 品牌与视觉资源
│   ├── icons/logo.svg              # 源项目官方矢量 Logo
│   ├── images/logo-banner.svg      # 源项目官方 Banner
│   └── icons/tray_icon.png         # 系统托盘图标
├── lib/
│   ├── core/                       # 国际化字典与核心工具
│   │   └── i18n.dart               # 零依赖中英文双语字典
│   ├── models/                     # 领域实体模型
│   │   ├── agent_profile.dart      # 节点配置与序列化 (JSON/YAML)
│   │   ├── runtime_state.dart      # 进程运行状态与日志缓冲
│   │   ├── metrics_data.dart       # 流量吞吐与活跃流模型
│   │   └── signal_profile.dart     # 信令服务配置模型
│   ├── services/                   # 核心业务服务层
│   │   ├── binary_manager.dart     # 二进制路径管理与版本回显
│   │   ├── process_supervisor.dart # 多进程守护与动态端口调度
│   │   ├── metrics_service.dart    # Prometheus 指标轮询器
│   │   ├── diagnostic_service.dart # RFC 3489 NAT 探测与 STUN 测速
│   │   ├── config_repository.dart  # 配置本地存储与导入导出
│   │   └── desktop_service.dart    # 窗口管理、系统托盘与网络自愈
│   ├── state/
│   │   └── app_state.dart          # 全局响应式状态机
│   ├── ui/                         # 现代化桌面界面层
│   │   ├── main_window.dart        # 侧边栏与主窗口布局
│   │   ├── dashboard/              # 流量看板与流掌控仪
│   │   ├── agents/                 # 多节点卡片列表与三模编辑弹窗
│   │   ├── diagnostics/            # 网络诊断与本地信令卡片
│   │   ├── logs/                   # 终端风格实时日志控制台
│   │   ├── settings/               # 二进制配置、更新检测与备份
│   │   └── share/                  # 二维码与格式化分享卡片弹窗
│   └── main.dart                   # 应用主入口
├── test/                           # 单元与组件测试
│   ├── core_test.dart              # 核心业务逻辑测试
│   └── widget_test.dart            # 桌面 UI 渲染与导航烟雾测试
└── .github/workflows/
    └── build-and-release.yml       # 跨平台 CI 自动拉取二进制打包发版流水线
```

---

## 🚀 本地开发与构建指南 (Build & Run)

### 前置条件
- [Flutter SDK](https://flutter.dev/) (>= 3.50.0)
- Windows 10/11 (已启用开发者模式)
- Visual Studio (推荐安装 C++ 桌面开发工作负载以构建原生可执行程序)

### 常用命令
```bash
# 1. 获取依赖
flutter pub get

# 2. 静态代码分析
flutter analyze

# 3. 执行测试套件
flutter test

# 4. 本地启动运行 (Windows 桌面)
flutter run -d windows

# 5. 构建 Windows Release 生产安装包
flutter build windows --release
```

---

## 📦 自动化 CI/CD 构建与发布 (GitHub Actions)

项目配备了工业级跨平台构建流水线 [build-and-release.yml](.github/workflows/build-and-release.yml)：
1. **触发方式**：打上 `v*` 标签并推送到仓库，或在 Actions 页面手动点击 `workflow_dispatch` 执行。
2. **上游二进制自动搭载**：CI 自动通过 GitHub API 下载源项目 `BeingNoAbility/WebRTC-Gateway` 的最新发布包，提取对应系统架构的 `agent[.exe]` 与 `signal[.exe]` 并打包进分发目录。
3. **输出资产**：自动生成包含可执行程序与底层二进制的开箱即用绿色压缩包（`webrtc-gateway-gui_v1.0.0_windows_amd64.zip` 等），附带 SHA256 校验和并自动发布 GitHub Release。

---

## 📄 开源许可证 (License)

本项目遵循 [MIT License](LICENSE) 开源协议。
