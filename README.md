# AngleLive-mod · tvOS 优化版

基于上游 **AngelLive** 的 tvOS 端重写版本：更轻量、更流畅、更贴近 Apple 原生体验。
开源协议与上游一致（**GPLv3**，见 `LICENSE.txt`）。

## 本版与上游的差异

新增独立宿主 **`AngelLiveTVOS2`**（上游 `AngelLiveTVOS` 保留不变），围绕"行级数据 + 统一图片管线 + 焦点集中路由"重建：

- **导航**：系统 `TabView`（推荐 / 收藏 / 平台 / 搜索 / 设置）
- **推荐页**：插件首页 feed、轮播与分区横排
- **房间列表**：分类侧栏按主分类折叠、焦点近底部分页、播放键刷新
- **收藏**：分组（不分组 / 直播状态 / 平台）与排序（默认 / 人气 / 观看次数），页内下拉菜单切换并记忆
- **收藏备份**：手机扫码导出 JSON、导入时选择**合并 / 覆盖**（兼容上游两种备份格式）
- **历史记录**：最近观看网格与一键清空
- **播放器**：KSPlayer 内核、共享恢复协调器、清晰度/弹幕/收藏/关联房间控制层
- **设置**：两栏结构（品牌区 + 菜单与子页），账号登录（扫码 / Cookie）、插件管理（订阅源 / 安装 / 更新 / 卸载）、通用 / 弹幕 / 同步 / 开源许可 / 关于
- **性能**：封面与头像按显示尺寸降采样解码、行级数据驱动、无全屏实时模糊材质、无常驻动画渐变

## 构建

- 工具链：Xcode 27.x（本仓库以 27.2 验证），Swift 6 模式
- 打开 `AngelLive.xcworkspace`，scheme 选 **`AngelLiveTVOS2`**
- **只能用真机调试**：KSPlayer 以闭源二进制分发，xcframework 不含 tvOS 模拟器切片（`SUPPORTED_PLATFORMS = appletvos`）
- 依赖按仓库 `Package.resolved` 解析（KSPlayer 上游 `kingslay/KSPlayer @ 7d6b4ce`、FFmpegKit 9.0.2）

## 安装

1. **atvloadly（推荐）**：直接安装 Release 附件的未签名 IPA，由 atvloadly 重签并安装到 Apple TV。
2. **Xcode 真机**：选 `AngelLiveTVOS2` → 运行目标选 Apple TV → 团队选你的开发者账号（本仓库附个人团队本地调试配置：Bundle ID `will.angellive2`，团队 `8ACFUGV9N8`；个人团队签名 7 天有效）。

> 本版**不包含** iCloud 与推送能力：无权限安装下收藏/书签/插件源/登录信息同步自动降级为仅本地，不会闪退。

## 已知限制

- iCloud 同步不可用（无权限签名环境），收藏等数据保存在本机
- Top Shelf 扩展未随新版启用（上游扩展仍在）
- 短剧播放页未随新版移植
- 插件需在应用内「设置 → 插件管理」添加订阅源后安装；本应用与上游 App 是独立容器，数据不共享

## Release

- 版本：**1.0.0-mod**
- 附件：`AngelLiveTVOS2-unsigned.ipa`（未签名，需自行重签/侧载安装）

## 许可

与上游项目一致：**GNU General Public License v3.0**。详见 `LICENSE.txt`。
