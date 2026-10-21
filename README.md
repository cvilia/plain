# 素记 Plain

本地优先的极简记账应用（Flutter）。

## 特性

- **极简记账**：数字键盘 + 分类预选，**点 OK 保存**
- **记账月**：可配置起始日（1–28 日），报表按记账月切期
- **本地加密**：SQLCipher 全库加密，密钥在系统安全区
- **10 套主题** × 浅深两态，默认素白
- **备份**：密码保护的 `.sujibak` 备份，恢复前预览
- **离线全功能**：无账号、无广告、无付费墙（V1.0）

## 技术栈

| 项 | 选型 |
|---|---|
| 框架 | Flutter + Riverpod |
| 数据库 | `sqlite3` + SQLCipher（hook `source: sqlcipher`） |
| 架构 | domain / data / features 分层 |
| 金额 | int64 分，禁 double |

## 开发

```bat
cd plain
flutter pub get
flutter test
```

Android 构建见 `AGENTS.md`（flavor：`dev` / `prod`）。

## 目录

- `lib/app` — 壳、主题、设置、路由
- `lib/domain` — 实体、用例、服务
- `lib/data` — sqlite、仓储、同步
- `lib/features` — 功能 UI
- `lib/design_system` — 令牌组件

产品与架构文档见上级目录 `01-`～`14-` 系列。
使用小米MiSans字体，需要遵循字体使用协议
