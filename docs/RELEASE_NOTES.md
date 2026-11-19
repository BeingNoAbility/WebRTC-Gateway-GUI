## [v2.3.2] - 2026-11-20

### 核心更新与修复 (Core Updates & Fixes)

- **跨平台现代化统一图形界面 (Cross-Platform Flutter GUI)**：
  - 基于 Material 3 与 Cyber Slate 调色盘实现 Windows 桌面与 Android 移动端统一视觉风格，支持暗黑/明亮主题无缝切换。
  - **全屏幕自适应与零溢出重构**：引入双层 `LayoutBuilder` 与 `Wrap` 流式排版，彻底消除手机竖屏（360px ~ 480px）在日志控制台、信令端、访客中心与 Agent 卡片等 4 处屏幕上的黄黑斑马线溢出。
- **Windows 桌面端增强与系统托盘常驻 (Desktop Tray & Hardening)**：
  - 拦截主窗口关闭事件，支持平滑最小化至 Windows 系统托盘后台运行，保障 WebRTC 穿透与信令服务持续在线；提供托盘快捷菜单支持一键批量启停与彻底退出。
  - **官方 Cyber Shield 图标与 PE 资源硬注入**：利用 `go-winres` 为单文件版嵌入多尺寸官方盾牌图标（ico）、GUI 清单与版本元数据，注入 Authenticode 数字签名有效规避杀毒软件误报。
- **多 Agent 集群并发与时效安全直连 (Multi-Agent & HMAC Sharing)**：
  - 支持多 Agent 实例独立配置与并发管理，内置动态递增端口分配机制杜绝 Prometheus 端口碰撞。
  - 本地纯数学计算 HMAC-SHA256 时效安全签名，一键生成限时免密直连分享链接与高清二维码。

### 破坏性变更 (Breaking Changes)

- 无 (None)。严格向下兼容既有配置与官方内核。

### 关联上游内核 (Upstream Kernel)

- 核心对齐：[WebRTC-Gateway v2.3.2](https://github.com/BeingNoAbility/WebRTC-Gateway/releases/tag/v2.3.2)
