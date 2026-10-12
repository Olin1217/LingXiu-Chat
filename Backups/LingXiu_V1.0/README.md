# 灵嗅（LingXiu）iOS 26 MVP

这是根据《[灵嗅（LingXiu）详细功能界面 PRD](LingXiu_详细功能界面PRD_V1.0.md)》从零创建的原生 SwiftUI 工程，目标平台为 iOS / iPadOS 26。

- App 显示名称：`灵嗅`
- 英文名及工程标识：`LingXiu`

## 当前已实现

- 三页新用户引导与游客体验
- Apple 原生登录控件入口
- 四个系统标签页：分析、人物、记录、我的
- 截图输入、相册多选、相机、剪贴板与截图排序
- 基于 Apple Vision 的设备端中文 OCR，可手动校对
- 自动遮挡顶部身份区、识别到的人脸与昵称，并提供可点选的手动打码编辑器
- 文字输入和模板化描述
- 人物、身份、权力关系、场景等背景补充
- 分步分析状态、证据化分析结果和风险提示
- 回应目标、语气、长度、关系温度和立场强度设置
- 三种差异化回复、复制、收藏、编辑和实时风险检查
- 人物角色卡创建、编辑、沟通画像、雷区、策略与历史互动
- 分析记录、筛选、收藏、删除、结果反馈和数据导出
- 回复偏好、通知、隐私、无痕分析和清空数据
- 每日免费次数限制和本地持久化
- 核心分析与回复生成单元测试

## 原生设计方式

界面采用 Apple 系统组件，而不是复制 Figma 画布中的像素图层：

- `NavigationStack` / `TabView` 负责导航与标签栏
- `List` / `Form` / `Section` 负责列表和表单
- `Picker`、`Toggle`、`Slider`、`PhotosPicker`、`ShareLink` 使用系统交互
- SF Symbols 负责图标
- 系统语义色和 Dynamic Type 负责深色模式与文字缩放
- iOS 26 下由系统提供 Liquid Glass 导航、标签栏和按钮表现

提供的 Figma Community 链接是社区文件页面，不是带 `node-id` 的可读取设计节点，因此本工程按 iOS 26 原生组件规范实现，没有猜测或硬编码画布坐标。

## 运行

1. 使用 Xcode 26 或更新版本打开 `LingXiu.xcodeproj`。
2. 在项目的 Signing & Capabilities 中选择自己的开发团队。
3. 选择 iOS 26 模拟器或设备，运行 `LingXiu` scheme。
4. 如需测试 Apple 登录，请为 Bundle ID 配置 Sign in with Apple capability；不配置时仍可完整使用游客流程。

## 已验证

- Xcode 26.6 / iOS 26.5 SDK 编译成功
- iPhone 17（iOS 26.5）模拟器安装和测试成功
- 首次引导与分析首页完成视觉冒烟检查
- `LocalAnalysisEngineTests` 共 5 项测试全部通过
- Asset Catalog JSON 与 Xcode 工程文件校验通过

## AI 接入说明

当前版本使用 `LocalAnalysisEngine` 提供可离线运行的三类演示分析（职场、客户、关系沟通），用于验证完整产品闭环。它不会把聊天发到外部服务，也不应被当作生产级 AI 判断。

接入真实模型时，应保持现有 `AnalysisDraft` / `AnalysisResult` 数据结构，并替换 `LocalAnalysisEngine.analyze` 与 `generateReplies` 的实现。生产环境还必须补齐：

- 服务端鉴权、限流和错误恢复
- 传输与存储加密
- 数据保存期限和删除接口
- 无痕分析的端到端保证
- 敏感内容安全策略和高风险场景提示
- App Store 商品、订阅验证和恢复购买

## 目录

```text
LingXiu/
├── App/            应用入口、导航和全局状态
├── Components/     可访问的共用界面组件
├── Design/         系统语义色与 iOS 26 样式
├── Features/       分析、人物、记录、我的
├── Models/         产品数据结构
├── Resources/      Asset Catalog
└── Services/       本地分析和 Apple Vision OCR
```
