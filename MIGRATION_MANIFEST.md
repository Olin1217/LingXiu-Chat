# LingXiu 迁移副本

本目录是灵嗅（LingXiu）工程的独立迁移副本，供新的 Codex / GPT 账号继续开发。

## 已迁移内容

- `LingXiu.xcodeproj`：当前 V1.01 Xcode 工程
- `LingXiu/`：Swift / SwiftUI 源码、原生资源、开发 CA 与方舟服务
- `LingXiuTests/`：单元测试、交互状态测试与联网集成测试
- `Server/`：灵嗅代理、Nginx、systemd、Docker、OpenAPI、数据库迁移、部署/备份/检查脚本
- `Scripts/`：模拟器信任配置和回归脚本
- `Backups/`：V1.0、GPT 设计前 V1.01、积分记录功能前的历史备份
- `Documentation/`：产品 PRD、服务器基础设施清单、命名方案和火山方舟官方接入文档

## 有意排除的内容

- `.deriveddata/`：本机 Xcode 编译缓存、临时测试结果和索引，迁移后可由 Xcode 重新生成
- `.DS_Store`：macOS 文件夹显示缓存
- `/etc/lingxiu-api.env`：服务器上的方舟 API Key 和代理令牌不在本地工程中，也不会复制到移动硬盘

## 开始开发

1. 用 Xcode 打开 `LingXiu.xcodeproj`。
2. 选择 iOS 26 模拟器或已连接的开发设备。
3. 运行 `LingXiu` Scheme。
4. 如需真实联网联调，按 `README.md` 与 `Server/README.md` 配置环境变量；不要把长期 API Key 写入源码、Info.plist、图片或提交记录。

