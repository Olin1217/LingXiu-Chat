# 灵嗅（LingXiu）V1.01

灵嗅是一个使用 Apple 原生 SwiftUI 开发的 iOS / iPadOS 26 沟通分析 App。V1.01 只保留最核心的沟通分析和聊天角色卡功能。

- App 显示名称：`灵嗅`
- 英文名及工程标识：`LingXiu`
- 产品版本：V1.01
- App Store 技术版本：`1.0.1`（Build 2）
- 产品文档：[LingXiu V1.01 核心功能 PRD](/Users/hualong/Downloads/LingXiu_V1.01_核心功能PRD.md)

## V1.01 核心功能

### AI 沟通分析

- 从系统相册选择最多 3 张聊天图片
- 使用 Apple Vision 在设备本地识别中英文文字
- 也可以直接输入或修改聊天内容
- 可选择一张聊天角色卡作为分析背景
- 输出可能的含义、沟通建议和 3 个回答选项
- 回答支持一键复制

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

## 技术实现

- Xcode 26
- Swift 6
- SwiftUI
- Observation
- PhotosUI
- Apple Vision OCR
- 系统 `NavigationStack`、`TabView`、`List`、`Form` 和 SF Symbols

当前 `LocalAnalysisEngine` 是用于验证产品闭环的设备端演示分析器，不会把聊天内容上传到外部服务。接入真实 AI 服务时，需要在服务端补齐鉴权、加密、限流、敏感内容策略和数据删除机制。

## 运行

1. 使用 Xcode 26 或更新版本打开 `LingXiu.xcodeproj`。
2. 选择具体的 iOS 26 模拟器或已连接设备。
3. 运行 `LingXiu` Scheme。

## 已验证

- Xcode 26.6 / iOS 26.5 SDK 编译成功
- iPhone 17（iOS 26.5）模拟器安装和启动成功
- 6 项核心单元测试全部通过
- 系统照片选择器、角色卡创建、角色卡参与分析、3 个回答选项和复制回答均完成交互检查
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
