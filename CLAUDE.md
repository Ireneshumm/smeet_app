# Smeet — Claude Code 项目说明

Smeet 是一个 Flutter 运动社交 App（iOS / Android / Web），定位「高端四项运动的单身社交」：
网球 🎾、高尔夫 ⛳、滑雪 🎿、潜水 🤿。后端用 Supabase（Auth / Postgres+RLS / Edge Functions），
推送用 Firebase，错误监控用 Sentry，CI 在 GitHub Actions（push 到 main 自动打包 iOS 上传
TestFlight、打出签名安卓包）。设计规范集中在 `lib/core/theme/`（AppColors / AppSpacing /
AppIconSize / AppRadius / textTheme），改 UI 必须用这些 token。主要代码在 `lib/main.dart`
（大文件，part 结构）和 `lib/features/`。

## AI 员工（.claude/agents/）

### 员工名单

| 员工 | 负责 |
|---|---|
| `code-reviewer` | 代码审查：正确性、安全、可维护性、性能，分级给意见 |
| `ai-code-security-auditor` | AI 生成代码的安全审计：泄露的密钥、Supabase RLS 漏洞、提示注入，只报告不改码 |
| `mobile-app-builder` | 移动端功能开发：界面、动画、离线、平台集成 |
| `mobile-release-engineer` | 发版：签名证书、App Store / Play 提交、分阶段发布、审核被拒应对 |
| `payments-billing-engineer` | 支付：Stripe 集成、幂等扣款、webhook、订阅状态机、对账 |
| `backend-architect` | 后端与数据库：Supabase 表结构、RLS 策略、Edge Functions、API 设计 |
| `app-store-optimizer` | 商店优化（ASO）：关键词、截图、商店页转化 |
| `growth-hacker` | 增长：裂变机制、漏斗转化、留存实验 |
| `xiaohongshu-specialist` | 小红书内容策略与运营文案 |

### 任务自动分派

遇到下列任务时，自动派给对应员工（用 Agent/Task 工具，subagent 按上表 name 调用）：
- 审查 PR 或大段改动 → `code-reviewer`；涉及密钥 / RLS / AI 生成代码 → 再加 `ai-code-security-auditor`
- 新界面、新功能、Flutter 改动 → `mobile-app-builder`
- 证书、签名、提审、发布节奏问题 → `mobile-release-engineer`
- 一切收款 / Stripe / 订阅相关 → `payments-billing-engineer`
- 建表、改 RLS、Edge Function、API → `backend-architect`
- 商店文案、关键词、截图策略 → `app-store-optimizer`
- 涨粉、分享裂变、留存 → `growth-hacker`；小红书内容 → `xiaohongshu-specialist`

### 全员铁律

1. **密钥纪律**：不打印、不提交任何密钥 / 密码 / 令牌；不删除、不轮换所有者的凭证；
   发现疑似泄露只报告位置，不复述其值。
2. **最小改动**:只改任务需要改的地方；不顺手重构、不升级依赖、不删功能。
3. **大改动先问**：架构调整、删除代码路径、改 CI / 签名 / 登录配置、改 Supabase 表结构，
   先停下来征得所有者（Irene）同意。
4. **澳洲合规**：涉及法律、隐私（Privacy Act / APPs）、消费者保护（ACL）、支付的内容，
   一律按澳大利亚法规处理；拿不准就标注「需人工确认」。
5. **只提 PR**：改动走分支 + Pull Request，不直接推 main（所有者明确要求时除外）。

### 共享工作日志

每完成一项工作，在 PR 描述最后追加一行：

```
日期 | Claude Code | smeet_app | 员工 | 做了什么 | 结果 | 待 Irene 决定的事
```
