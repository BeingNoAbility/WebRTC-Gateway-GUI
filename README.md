# WebRTC Gateway Desktop GUI

<p align="center">
  <img src="assets/images/logo-banner.svg" alt="WebRTC Gateway Banner" width="820">
</p>

### 现代化跨平台 WebRTC 零客户端 P2P 内网穿透桌面客户端 (Windows 优先)
A modern cross-platform desktop GUI for **[WebRTC-Gateway](https://github.com/BeingNoAbility/WebRTC-Gateway)** built with Flutter & Dart.

---

## 🌟 核心特性 (Key Features)

- **多 Agent 实例并发管理 (Multi-Agent Concurrent Pool)**：支持同时配置并运行多个独立的穿透节点，内部自动动态调度 Prometheus 端口（如 `:9091`, `:9092`...），消除多实例端口冲突。
- **开箱即用与灵活核心管理 (Battery-Included & Custom Binaries)**：
  - GitHub CI 自动拉取上游 `BeingNoAbility/WebRTC-Gateway` 最新 Release 并搭载对应系统平台的二进制文件（解压即用，无需手动配置 Go 环境）。
  - 支持在设置中点选本地自定义 `agent` / `signal` 路径，自动执行 `-help` 探测并回显版本号，支持在线镜像加速下载与 `SHA256SUMS.txt` 校验更新。
- **三模全场景穿透 (Multi-Mode)**：
  - **本地服务反代 (`-target`)**：内置 Ollama (`11434`)、ComfyUI (`8188`)、Jellyfin (`8096`)、NAS (`5000`) 等常用本地应用端口预设。
  - **静态目录托管 (`-dir`)**：点选文件夹，一键通过 P2P 共享整个目录。
  - **单文件直传 (`-file`)**：点选大文件，生成点对点流式下载通道。
- **Multi-PC 物理链路聚合 (Trunking Slider)**：直观滑动条（1~8 路），突破 Chromium 单核 SCTP 吞吐瓶颈。
- **实时流量看板与节点会话监控 (Dashboard & Mux Monitor)**：
  - 实时绘制时间戳对齐的聚合上下行网速（B/s、KB/s、MB/s）与活跃流曲线。
  - 实时监控各节点活跃逻辑流、PeerConnection 链路与背压拒绝数，支持一键平滑重启重置节点通道（单流级 `RST_STREAM` 强杀在访客 Web Portal 右下角 HUD 悬浮球内提供）。
- **极速分享与安全防护 (Quick Share, HMAC-SHA256 & Safety Guards)**：
  - 自动生成 Web 直连访问 URL（`https://signal.domain/#node-id`）及移动端扫码二维码。
  - 支持本地及上游兼容的 **HMAC-SHA256 时效签名安全链接**（`?exp=...&sign=...`）与 `-sign-link` 临时签名锁模式，默认不在分享卡片暴露明文密码。
  - 对未设访客密码或允许 `*` 跨域的危险配置提供醒目安全确认拦截，防止内网服务意外裸奔。
- **网络诊断与打洞连通性优化 (Diagnostics)**：
  - **NAT 类型诊断 (RFC 3489 / 5780)**：探测 Open Internet、Cone NAT、Symmetric NAT (NAT 4)，提前获知 P2P 穿透潜力。
  - **公共 STUN 低延迟测速**：内置 Google、Cloudflare、腾讯、小米等 STUN 列表，异步 Ping 测速排序并支持一键应用最优服务器到全部节点。
- **本地信令服务端管理 (Local Signal Manager)**：
  - GUI 内一键启停内置 `signal`（默认开启 `-tls-auto` 自签证书与严格同源策略），专为局域网与私有信令部署打造。
- **桌面深度融合与稳定性 (Desktop Integration)**：
  - Windows 单实例互斥锁（重复点击自动唤起已有窗口）、Win32 `WM_GETOBJECT` 辅助桥崩溃防护。
  - 系统托盘常驻、关闭确认与静默开机自启动（`--minimized` + 节点/信令随软件自动拉起）。
  - **网络恢复自愈 (Network Auto-Heal)**：监听断网恢复跃迁，防抖后自动恢复在线穿透节点。
- **配置便携存储、主题与双语切换 (Portable Storage, Dark Mode & i18n)**：
  - 支持便携式配置落盘，一键导出/导入标准上游 `agent.yaml` / `server.yaml` 与全量 `.json` 备份。
  - 支持浅色 / 深色 / 跟随系统主题、MiSans 字体排版及简体中文与 English 原地热切换。

---

## 🏗️ 项目目录结构 (Project Structure)

```text
WebRTC-Gateway-GUI/
├── assets/                                 # 品牌视觉、托盘图标与字体资源
│   ├── fonts/MiSans-{Regular,Medium}.ttf   # MiSans 字体资源
│   ├── icons/{app_icon.ico,logo.svg,...}   # 应用与托盘图标
│   └── images/logo-banner.svg              # 官方 Banner
├── bin/.gitkeep                            # 本地可选调试二进制占位（默认不入库）
├── integration_test/
│   └── app_e2e_test.dart                   # Windows 真机交互 E2E 测试套件
├── lib/
│   ├── core/i18n.dart                      # 零依赖中英文双语字典
│   ├── models/                             # 领域实体模型与 YAML/JSON 序列化
│   │   ├── agent_profile.dart
│   │   ├── app_settings.dart
│   │   ├── metrics_data.dart
│   │   ├── runtime_state.dart
│   │   └── signal_profile.dart
│   ├── services/                           # 核心后台服务层
│   │   ├── autostart_service.dart          # 跨平台开机自启
│   │   ├── binary_manager.dart             # 二进制路径定位与版本探测
│   │   ├── config_repository.dart          # 原子持久化与导入导出
│   │   ├── desktop_service.dart            # 窗口、托盘与断网自愈
│   │   ├── diagnostic_service.dart         # RFC 3489 NAT 诊断与 STUN 测速
│   │   ├── metrics_service.dart            # Prometheus 指标轮询器
│   │   ├── process_supervisor.dart         # 多进程守护与命令行构造
│   │   └── update_service.dart             # GitHub Release 检查与校验更新
│   ├── state/app_state.dart                # 全局状态机
│   ├── ui/                                 # 桌面端 UI 视图层
│   │   ├── main_window.dart                # 侧边栏与主窗口壳
│   │   ├── dashboard/                      # 运行看板与节点会话监控
│   │   ├── agents/                         # 穿透节点列表与三模配置弹窗
│   │   ├── signal/                         # 本地信令服务控制面板
│   │   ├── diagnostics/                    # NAT 诊断与 STUN 测速页
│   │   ├── logs/                           # 实时日志控制台与单节点弹窗
│   │   ├── share/                          # 二维码与时效签名分享弹窗
│   │   └── settings/                       # 二进制配置、备份与版本更新页
│   └── main.dart                           # 应用主入口
├── linux/ | macos/ | windows/              # 跨平台原生宿主工程
├── test/                                   # 单元与组件渲染测试
│   ├── core_test.dart
│   └── widget_test.dart
└── .github/workflows/
    └── build-and-release.yml               # Windows/Linux/macOS CI 打包发布流水线
```

---

## 💻 平台支持说明 (Supported Platforms)

| 平台 | 发行包格式 | 运行环境与说明 |
| :--- | :--- | :--- |
| **Windows (`x64`)** | `webrtc-gateway-gui_<tag>_windows_amd64.zip` | **首要支持平台**：绿色便携压缩包，内置 `agent.exe` 与 `signal.exe`，解压双击即可使用 |
| **Linux (`x64`)** | `webrtc-gateway-gui_<tag>_linux_amd64.tar.gz` | 需系统具备 GTK3 及 `libayatana-appindicator3-1`（托盘依赖），建议配合 `zenity` 使用文件选择对话框 |
| **macOS (`arm64`)** | `webrtc-gateway-gui_<tag>_macos_arm64.zip` | 内置 `agent`/`signal` 于 `.app/Contents/MacOS/bin/`；未签名版本首次启动如被 Gatekeeper 拦截可执行 `xattr -dr com.apple.quarantine webrtc_gateway_gui.app` |

---

## 🚀 本地开发与构建指南 (Build & Run)

### 前置条件
- [Flutter SDK](https://flutter.dev/) (`>= 3.50.0` / Dart `>= 3.14.0`)
- **Windows**：Windows 10/11（开启开发者模式）+ Visual Studio C++ 桌面开发工作负载
- **Linux**：`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libayatana-appindicator3-dev`
- **macOS**：Xcode + CocoaPods

### 常用命令
```bash
# 1. 获取依赖
flutter pub get

# 2. 静态代码分析
flutter analyze

# 3. 执行单元与组件测试
flutter test -r expanded

# 4. 本地启动运行 (以 Windows 为例)
flutter run -d windows

# 5. 执行 Windows 真机交互 E2E 测试（需 bin/ 下放置 agent.exe 与 signal.exe）
flutter test integration_test/app_e2e_test.dart -d windows -r expanded

# 6. 构建 Release 产物
flutter build windows --release
```

---

## 📦 自动化 CI/CD 构建与发布 (GitHub Actions)

项目配备了跨平台构建流水线 [build-and-release.yml](.github/workflows/build-and-release.yml)：
1. **触发方式**：推送 `v*` 版本标签（例如 `v1.0.0`），或在 GitHub Actions 页面手动触发 `workflow_dispatch`。
2. **上游二进制自动搭载**：CI 自动下载 [BeingNoAbility/WebRTC-Gateway](https://github.com/BeingNoAbility/WebRTC-Gateway) 最新 Release 中匹配平台架构的 `agent[.exe]` 与 `signal[.exe]` 并嵌入发布产物。
3. **自动校验与发版**：并行构建 `windows-latest`、`ubuntu-latest`、`macos-latest`，生成 `SHA256SUMS.txt` 并发布 GitHub Release。

---

## 📄 开源许可证与致谢 (License & Acknowledgements)

- 本项目遵循 [MIT License](LICENSE) 开源协议。
- 上游 P2P 隧道核心来自 **[WebRTC-Gateway](https://github.com/BeingNoAbility/WebRTC-Gateway)**。
- 界面默认中文无衬线字体采用小米 **MiSans**。
