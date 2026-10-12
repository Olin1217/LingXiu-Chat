# 灵嗅服务器框架

这套框架遵循“当前能联调、以后能平滑上线”的原则。现阶段只有 ECS 和火山方舟 API，因此不会假装已接入域名、正式 CA 证书、云数据库、OSS、Apple 登录或短信服务。

## 当前已启用

- 阿里云 Ubuntu 24.04 ECS
- Nginx 公网反向代理，应用服务只监听 `127.0.0.1:8080`
- 公网只监听 HTTPS 443；Ubuntu 自带的 80 端口示例站点已停用
- IP 开发证书链与 iOS 叶证书固定，仅用于联调
- systemd 进程守护和最小权限运行用户
- `/health`、`/healthz` 健康检查
- `/v1/responses` 火山方舟代理
- API Key 仅保存在服务器 `/etc/lingxiu-api.env`
- 请求大小限制、每 IP 限流、关闭方舟响应存储、禁止远程图片 URL

## 已搭好但暂不启用

- `compose.yaml`：API 容器和可选 PostgreSQL profile
- `migrations/001_initial.sql`：用户、角色卡、会话、分析、消息、积分、订阅等初始结构
- `openapi.yaml`：当前接口与后续 MVP 接口契约
- `nginx/lingxiu-domain.conf.template`：备案域名和正式证书接入模板
- `scripts/backup.sh` / `restore.sh`：数据库备份恢复入口

数据库暂不保存真实用户聊天内容。原因是当前尚无正式登录、隐私协议和异机备份目标；iOS 继续使用设备本地存储。这样不会为了“先搭框架”而提前扩大敏感数据风险。

> iOS 26 的 ATS 不会仅凭 App 内打包的私有 CA 放行系统不信任的证书。IP 联调时还需把公开开发 CA 加入指定模拟器或开发测试机的系统信任库；叶证书固定仍会继续校验服务器身份。正式域名和受系统信任证书就绪后，应移除整套开发 CA 与指纹配置。

## 目录

```text
Server/
├── lingxiu_proxy.py          当前轻量后端
├── lingxiu-api.service       当前 systemd 服务
├── nginx-lingxiu.conf        IP 联调 Nginx 配置
├── Dockerfile
├── compose.yaml              容器化和可选数据库框架
├── migrations/               PostgreSQL 迁移
├── nginx/                    正式域名模板
├── scripts/                  部署、检查、备份、恢复
└── openapi.yaml              API 契约
```

## 当前部署（无需 Docker）

服务器上的真实环境文件必须预先存在，部署脚本不会创建、读取或输出任何密钥：

```bash
sudo ./scripts/deploy.sh
sudo ./scripts/check.sh https://182.92.71.158 /etc/lingxiu-api/tls/ca.pem
```

## 未来正式上线切换

1. 购买并备案域名，将 `api.<域名>` 解析到 ECS。
2. 使用 Certbot 或阿里云证书替换开发证书，并从 iOS 移除测试指纹。
3. 确认 Apple 登录、隐私协议和注销流程后启用账户数据接口。
4. 启用 PostgreSQL，并先完成异机/OSS 自动备份。
5. 购买 OSS 后，头像和聊天截图改为短时上传、到期删除；当前仍以内联图片直达 AI 且不落盘。
6. 接入 App Attest 和短期令牌，替换 App 内可轮换的共享代理令牌。

## 明确不做的事

- 不把 Ark API Key 写进 Swift、Info.plist、Docker 镜像或仓库。
- 不把 PostgreSQL 5432 或 Python 8080 暴露到公网。
- 不在没有备份的情况下开启服务端聊天记录持久化。
- 不用自签证书方案发布 App Store 正式版本。
