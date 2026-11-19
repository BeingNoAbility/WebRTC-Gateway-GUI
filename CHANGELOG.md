# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.3.2] - 2026-11-20

### Added
- 统一跨平台 GUI：针对 Windows 桌面端（NavigationRail 宽屏布局）与 Android 移动端（底部 NavigationBar 触控流）提供统一的 Cyber Slate Material 3 视觉体验。
- Windows 系统托盘常驻支持：支持关闭窗口时平滑最小化至任务栏小图标，提供快捷右键菜单（显示窗口、批量启动/停止 Agent、彻底退出）。
- 多 Agent 集群并发管理中心：支持同时创建、运行和独立监控多个 WebRTC 穿透实例，带动态递增端口防冲突分配（`:9091`, `:9092`...）。
- 时效安全直连分享：本地纯数学 HMAC-SHA256 签名算法，生成 1小时/24小时/7天/30天安全直连链接与动态二维码。
- 访客连接中心：常用节点收藏夹（Bookmarks）分类与一键浏览器直连。
- 信令中继服务端管理：单键启停本地私有信令中继，支持 Anti-CSWSH 跨域白名单与内存自签 TLS（`-tls-auto`）。
- 网络穿透诊断工具箱：内置 RFC 5389 UDP 报文探测测量 STUN/TURN RTT 延迟与 NAT 打洞探针。
- 自动化持续集成发版：新增 GitHub Actions 自动跟随源项目发版工作流（`auto_release.yml`）。
- 社区规范：增加 MIT 开源许可协议、Bug 报告与功能建议 Issue 模板。

### Changed
- 界面响应式全屏自适应重构：利用 `LayoutBuilder` 与 `Wrap` 重构日志终端控制台、信令服务卡片、访客节点卡片以及 Agent 穿透卡片，彻底消除 Android 手机竖屏（360px ~ 480px）下的全部斑马线溢出。
- Windows 可执行文件资源注入：通过 `go-winres` 注入官方 Cyber Shield 多尺寸图标、Windows GUI 清单与产品元数据。
- 杀软防报毒加固：单文件版注入 Authenticode 数字签名，并同步提供零释放行为的便携绿色解压包（Zip）。

### Fixed
- 修复 Android CI 构建缺失 Gradle Wrapper 的问题（纳管 `gradlew` 与 `gradle-wrapper.jar` 入库）。
- 修复 Windows 单文件版因误设 `HideWindow` 导致的无感隐藏闪退问题。
- 修复移动端运行状态下 Prometheus 监控指标行溢出屏幕的问题。
