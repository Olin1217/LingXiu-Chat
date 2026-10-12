# 灵嗅 App 上线前服务器与基础设施配置清单

如果你现在已经有：

- 阿里云服务器
- AI 模型 API（例如豆包 / 火山方舟）

那么「灵嗅」要真正跑起来，还需要补齐下面这些基础设施与配置。

---

## 一、第一优先级：现在就要配置

| 项目 | 作用 | 现在是否必须 |
|---|---|---|
| 域名 | 给后端 API 一个稳定地址 | 必须 |
| DNS 解析 | `api.xxx.com` 指向服务器 | 必须 |
| HTTPS / SSL | App 安全请求后端 | 必须 |
| Nginx | 接收公网请求、反向代理 | 必须 |
| 后端服务 | 用户、人物卡、AI 分析、灵感值等业务逻辑 | 必须 |
| 数据库 | 保存用户、人物、记录、额度等 | 必须 |
| 环境变量 `.env` | 存放 AI Key、数据库密码等 | 必须 |
| 安全组 / 防火墙 | 只开放需要的端口 | 必须 |
| 进程守护 | 后端挂了自动重启 | 必须 |

推荐最简单的结构：

```text
灵嗅 iOS App
      ↓
https://api.lingxiu.xxx
      ↓
Nginx
      ↓
灵嗅 Backend
      ↓
┌──────────────┬──────────────┐
数据库          火山方舟 API
PostgreSQL      豆包 / 其他模型
```

---

## 二、数据库

建议直接使用：

**PostgreSQL**

早期可以先装在这台 2C2G ECS 上。

主要可以存：

```text
users
用户

person_profiles
人物角色卡

analysis_records
分析记录

messages
聊天内容

user_preferences
回复偏好

inspiration_balance
灵感值余额

inspiration_records
灵感值收支记录

subscriptions
会员状态
```

MVP 阶段可以先不接 Redis，避免增加复杂度。

---

## 三、图片 / 聊天截图

灵嗅后面会涉及：

- 微信聊天截图
- 用户头像
- 图片上传

不建议长期直接存在服务器磁盘。

建议配置：

**阿里云 OSS**

推荐结构：

```text
用户上传截图
     ↓
   OSS
     ↓
后端拿到文件地址
     ↓
发给 AI 分析
```

这样以后迁服务器时，图片不需要跟着迁。

---

## 四、域名建议

假设你的主品牌域名是：

```text
lingxiu.com
```

可以拆成：

```text
www.lingxiu.com
官网

api.lingxiu.com
App 后端

cdn.lingxiu.com
图片/CDN（以后）

admin.lingxiu.com
后台管理（以后）
```

最重要的是：

```text
api.lingxiu.com
```

App 应该始终请求域名，不要直接写：

```text
http://123.123.123.123
```

否则以后服务器 IP 发生变化会很麻烦。

---

## 五、HTTPS / SSL

建议使用：

```text
Nginx
+
Let's Encrypt SSL
+
Certbot 自动续签
```

最终 App 请求应该类似：

```text
https://api.xxx.com/v1/analyze
```

而不是：

```text
http://服务器IP:3000
```

---

## 六、AI API Key 不要放进 iOS App

这一点非常重要。

不要让：

```text
iPhone
 ↓
直接调用豆包
```

否则用户反编译 App 后，可能获取你的 API Key。

正确架构应该是：

```text
iPhone
 ↓
灵嗅服务器
 ↓
豆包 API
```

API Key 只存在服务器的：

```text
.env
```

例如：

```text
ARK_API_KEY=xxxx
DATABASE_URL=xxxx
JWT_SECRET=xxxx
```

并且：

**`.env` 绝对不能提交到 GitHub。**

---

## 七、登录系统

需要提前决定用户怎么登录。

灵嗅如果先做 iOS，MVP 建议：

**Apple 登录 + 游客模式**

之后国内用户量起来后，再增加：

**手机号验证码登录**

如果做手机号登录，还需要配置：

```text
阿里云短信 / 腾讯云短信
```

不过手机号登录涉及实名、短信签名、模板审核等流程，第一版可以先不做。

推荐路径：

```text
游客体验
↓
Apple 登录
↓
后续再增加手机号登录
```

---

## 八、第一版后端接口建议

MVP 可以先做：

```text
POST /auth/login

GET /user

POST /analysis
分析聊天

GET /analysis/:id
查看分析

GET /analysis
历史记录

POST /persons
创建人物卡

GET /persons
人物列表

PUT /persons/:id
更新人物

DELETE /persons/:id

POST /upload
上传截图

GET /inspiration
灵感值

DELETE /account
注销账户
```

灵嗅真正复杂的地方，不是服务器，而是：

- Prompt 设计
- 上下文处理
- 人物关系
- AI 输出结构
- 长期人物画像

---

## 九、AI 输出建议使用结构化 JSON

不要让模型每次都自由返回一大段自然语言。

最好从第一版就要求结构化 JSON，例如：

```json
{
  "surface_meaning": "表面意思",
  "possible_intentions": [
    {
      "intent": "可能是在提醒你",
      "confidence": 0.72,
      "evidence": "..."
    }
  ],
  "relationship_signal": "...",
  "risk": "...",
  "suggested_action": "...",
  "replies": [
    {
      "style": "稳妥",
      "content": "..."
    }
  ]
}
```

这样 iOS 前端才能稳定渲染。

---

## 十、服务器安全

服务器初次配置时就建议处理好。

公网只开放：

```text
22    SSH
80    HTTP
443   HTTPS
```

数据库端口：

```text
5432
```

**不要直接开放公网。**

Node / Python 后端端口：

```text
3000 / 8000
```

也不建议直接开放公网，让 Nginx 反向代理即可。

后续最好逐步增加：

- 禁止 root 密码直接 SSH
- SSH Key 登录
- 创建普通 sudo 用户
- Fail2ban
- 自动安全更新

---

## 十一、日志与监控

至少需要知道服务器什么时候挂了。

第一版可以保留：

```text
Nginx logs
后端 logs
数据库 logs
```

同时增加：

```text
/health
```

例如：

```text
GET https://api.xxx.com/health
```

返回：

```json
{
  "status": "ok"
}
```

以后 Codex 也可以用这个接口自动检查部署是否成功。

---

## 十二、备份

数据库一定要做自动备份。

推荐：

```text
每天凌晨
↓
pg_dump
↓
压缩
↓
上传 OSS
↓
保留最近 7 / 30 天
```

否则服务器磁盘损坏一次，用户的人物卡、分析记录、灵感值等数据都可能丢失。

---

## 十三、第二阶段再配置

这些暂时不需要在 MVP 阶段全部上：

```text
Redis
CDN
消息队列
RDS
负载均衡
多服务器
Kubernetes
GPU 服务器
Elasticsearch
```

灵嗅第一版完全没必要一开始就引入这么多复杂度。

---

## 十四、当前最合适的整体配置

建议当前直接采用：

```text
阿里云 ECS
2C2G
Ubuntu 24.04

│
├── Nginx
│
├── Docker / Docker Compose
│
├── 灵嗅 Backend
│   └── Node.js 或 Python
│
├── PostgreSQL
│
└── 自动备份

外部服务：
├── 阿里云 OSS
├── 火山方舟 / 豆包
├── SSL
└── Apple Sign in
```

这套已经足够支撑灵嗅第一版正式上线。

---

## 十五、部署方式建议

如果后面准备让 Codex 配服务器，不建议让它零散地手工安装。

最好从第一版就整理成：

```text
lingxiu-server/
├── app/
├── docker-compose.yml
├── Dockerfile
├── nginx/
├── scripts/
│   ├── deploy.sh
│   ├── backup.sh
│   └── restore.sh
├── .env.example
└── README.md
```

这样以后无论是：

- 阿里云北京 → 阿里云上海
- 阿里云 → 火山引擎
- 2C2G → 4C8G
- 更换服务器公网 IP

都可以更快完成迁移。

---

## 十六、建议的实施顺序

建议按这个顺序推进：

```text
1. 买好 ECS
2. Ubuntu 24.04 初始化
3. 配置 SSH Key
4. 安装 Docker / Docker Compose
5. 部署 Nginx
6. 配置域名与 DNS
7. 配置 HTTPS / SSL
8. 部署灵嗅 Backend
9. 安装 PostgreSQL
10. 配置 .env
11. 接入火山方舟 / 豆包 API
12. 配置 OSS
13. 接入 Apple 登录
14. 增加 /health
15. 配置自动备份
16. 再开始 iOS 真机联调
```

---

## 最终建议

灵嗅当前阶段不需要追求复杂架构。

重点是：

**服务器简单、数据安全、AI Key 不泄露、接口稳定、后续容易迁移。**

第一版推荐维持：

> 阿里云 ECS + Ubuntu 24.04 + Docker Compose + Nginx + PostgreSQL + OSS + 火山方舟 / 豆包 API

等真实用户量和业务复杂度上来以后，再逐步增加 Redis、RDS、CDN、负载均衡等能力。
