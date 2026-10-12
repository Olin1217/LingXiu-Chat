# 灵嗅 Chat（LingXiu Chat）V1.01

> Understand the signals behind the words. Know what to say next.

灵嗅 Chat 是面向中文沟通场景的 AI 沟通分析助手，帮助用户理解话语背后的可能含义、识别沟通信号，并在保留自主判断的前提下组织下一步表达。完整产品概览见 [`Documentation/LingXiu_Product_Overview.md`](Documentation/LingXiu_Product_Overview.md)。

灵嗅是一个使用 Apple 原生 SwiftUI 开发的 iOS / iPadOS 26 沟通分析 App。V1.01 只保留最核心的沟通分析和聊天角色卡功能，并采用以输入为中心的 AI 会话体验。

- App 显示名称：`灵嗅`
- 英文名及工程标识：`LingXiu`
- 产品版本：V1.01
- App Store 技术版本：`1.0.1`（Build 2）
- 产品文档：[LingXiu V1.01 核心功能 PRD](Documentation/LingXiu_V1.01_核心功能PRD.md)

## V1.01 核心功能

### AI 沟通分析

- GPT 式单页会话流程，分析结果直接衔接在用户消息下方
- 底部常驻原生输入器，支持连续提交不同沟通场景
- 从系统相册选择最多 3 张聊天图片
- 使用 Apple Vision 在设备本地识别中英文文字
- 也可以直接输入或修改聊天内容
- 可选择一张聊天角色卡作为分析背景
- 输出可能的含义、沟通建议和 3 个回答选项
- 每个回答卡片右上角支持复制和“优化”，优化后会把原回答引用到输入框上方
- 分析结果底部支持复制和系统分享

### 聊天角色卡

- 用户自行创建、编辑和删除角色卡
- 支持填写称呼、关系和身份
- 支持用自然语言描述这个人及其讲话特点
- 可选填写星座、生日、生辰八字或出生时间、MBTI、讲话风格
- 角色卡作为聊天分析的补充上下文
- 星座、MBTI 和生辰信息不会被用于确定性的人格或命运判断

## 本版本已移除

V1.01 不再包含登录、会员、分析配额、记录中心、个人中心、模板场景、复杂多步骤分析、回复风格调节、手动图片打码和数据导出等非核心功能。

V1.0 完整备份位于：`Backups/LingXiu_V1.0/`

GPT 式会话界面重构前的 V1.01 快照位于：`Backups/LingXiu_V1.01_PreGPTDesign/`

## 技术实现

- Xcode 26
- Swift 6
- SwiftUI
- Observation
- PhotosUI
- Apple Vision OCR
- 可选的火山方舟 Responses API（Doubao-Seed-Evolving）
- 系统 `NavigationStack`、`List`、`Form`、PhotosPicker、ShareLink 和 SF Symbols
- iOS 26 原生 Liquid Glass 工具栏、按钮和输入器表面

当前 `LocalAnalysisEngine` 是离线兜底分析器。云端分析使用原生 `URLSession` 请求 `doubao-seed-evolving`。应用会明确设置 `store: false`，不让方舟保存 Responses 内容；请求失败或离线时自动回退到本地分析，并向用户说明本次使用了本地能力。

### 配置灵嗅服务端代理（发布版本）

发布版本应由灵嗅自己的 HTTPS 服务端持有火山方舟 API Key，iOS 客户端只配置非敏感代理地址。代理需兼容方舟 `POST /api/v3/responses` 的请求与响应格式，并在服务端注入 API Key、固定模型、执行限流与请求体大小限制。

开发时可在 Scheme 的环境变量中设置完整代理接口：

```text
LINGXIU_AI_ENDPOINT=https://<灵嗅服务域名>/v1/responses
LINGXIU_PROXY_TOKEN=<服务端生成的可轮换访问令牌>
LINGXIU_PINNED_CERTIFICATE_SHA256=<仅在使用自签名测试证书时配置的 SHA-256 指纹>
```

正式包可通过生成的 Info.plist 键 `LingXiuAIEndpoint` 配置相同的非敏感 HTTPS 地址，并通过 `LingXiuProxyToken` 配置可轮换的代理访问令牌。该令牌只用于限制代理滥用，不能替代服务端限流，也绝不能使用火山方舟长期 API Key；生产阶段应进一步接入 App Attest 并由服务端签发短期令牌。

当前大陆测试服务器没有已备案域名时，可由 `LingXiuPinnedCertificateSHA256` 固定服务器自签名证书。固定逻辑同时校验目标主机和完整叶证书摘要，不会修改其他 HTTPS 主机的系统信任策略。正式上线应替换为已备案域名和受系统信任的 CA 证书，并移除该测试指纹。

iOS 26 的 App Transport Security 仍要求开发 CA 位于测试设备的系统信任库；App 内随包携带的公开 CA 和叶证书固定不能代替系统信任。首次使用某个模拟器联调 IP HTTPS 时，先启动该模拟器并执行：

```bash
DEVELOPER_DIR="/完整路径/Xcode.app/Contents/Developer" \
  ./Scripts/configure_simulator_trust.sh <模拟器 UUID>
```

本机 iPhone 17 Pro（iOS 26.5）已经完成这一步。真实测试机仅可在开发阶段手动安装同一公开 CA，并在“设置 → 通用 → 关于本机 → 证书信任设置”中启用完全信任；正式发布包不得要求用户安装开发证书。

### 直连火山方舟（仅本地开发测试）

不要把 API Key 写进 Swift 源码、Info.plist、图片或提交记录。打开 Xcode 的 LingXiu Scheme → Run → Arguments → Environment Variables，添加：

```text
ARK_API_KEY=<从火山方舟控制台生成的密钥>
```

页面中使用的模型 ID 是 `doubao-seed-evolving`。运行后可打开“更多 → 隐私与分析说明”确认当前配置方式；未配置云端连接时显示本地演示分析。发布版本不得把长期 API Key 放进客户端。

## 运行

1. 使用 Xcode 26 或更新版本打开 `LingXiu.xcodeproj`。
2. 选择具体的 iOS 26 模拟器或已连接设备。
3. 运行 `LingXiu` Scheme。

## 已验证

- Xcode 26.6 / iOS 26.5 SDK 编译成功
- iPhone 17 Pro（iOS 26.5）模拟器安装、启动和开发 CA 信任配置成功
- 45 项常规单元与交互状态测试全部通过；1 项联网集成测试另行启用后通过
- 客户端 → HTTPS 证书固定 → 灵嗅代理 → 火山方舟的真实链路已经打通
- `doubao-seed-evolving` 已开通；服务器真实 Responses API 请求返回 HTTP 200，联网集成测试必须得到有效分析和回答选项
- 系统照片选择器、角色头像上传、角色卡创建、角色卡参与分析、3 个回答选项、复制、优化引用和分享均完成交互检查
- V1.0 备份工程完成独立编译验证

## 目录

```text
LingXiu/
├── App/            App 入口和全局状态
├── Design/         系统语义色与 iOS 26 样式
├── Features/
│   ├── Analysis/   图片/文字输入、AI 分析和回答选项
│   └── RoleCards/  聊天角色卡
├── Models/         核心数据结构
├── Resources/      Asset Catalog
└── Services/       本地分析和 Apple Vision OCR
```
