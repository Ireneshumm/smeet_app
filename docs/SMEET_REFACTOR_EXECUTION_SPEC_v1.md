# Smeet 技术重构与产品升级执行文档

**Version:** v1.0  
**Project:** Smeet  
**Document Type:** Engineering Execution Spec  
**Primary Goal:** 将 Smeet 从「约球工具」升级为「内容驱动 + 匹配驱动 + 约局转化驱动」的运动社交平台  
**Target Executor:** Cursor / Flutter Engineer / Full-stack Engineer  

---

## 0. 文档用途

本文件用于指导 Cursor 对现有 Smeet Flutter + Supabase 项目进行**渐进式**重构与功能升级。

**核心要求：**

1. 不做一次性大重构  
2. 每一步都必须**可编译、可运行、可回滚**  
3. 优先搭建**可扩展骨架**，再逐步接入真实数据  
4. 不破坏现有**登录、聊天未读、Create Game**等已可用逻辑  
5. 所有新模块先支持 **placeholder / mock data**，再替换为 Supabase 实现  

---

## 1. 当前产品定位与重构目标

### 1.1 当前问题

现有 Smeet 更偏向：

- 工具型约局 App  
- 用户主要动作：建局 / 加局 / 聊天 / 看资料  
- 缺少内容流、冷启动内容池、持续回访机制  

**结果：**

- 用户没有每天打开的理由  
- 新用户进入后可能看到「内容空白」  
- 社交关系链条不够完整  
- 缺乏内容 → 匹配 → 聊天 → 约局的闭环  

### 1.2 目标定位

Smeet 需要升级为：

**内容驱动 + 匹配驱动 + 约局转化驱动** 的运动社交平台  

**参考拆解：**

- 小红书：图文种草 / 搜索 / 收藏 / 地点页  
- TikTok：短视频流 / 兴趣分发 / 停留时长  
- Tinder：滑卡匹配 / 即时反馈 / 低门槛破冰  

### 1.3 最终产品核心链路

用户进入 App 后可：

1. 在 **Feed** 刷内容（图文 / 视频 / 组局）  
2. 在 **Swipe** 滑人 / 滑局 / 滑内容  
3. 在 **Create** 快速发笔记 / 发视频 / 开局  
4. 在 **Inbox** 处理匹配、局聊、私聊  
5. 在 **Profile** 展示动态运动名片  

---

## 2. 技术执行总原则

### 2.1 重构原则

- 采用**渐进式**重构，不做全量推翻  
- 新功能一律**先做壳，再接真实数据**  
- **每个 Sprint 只改一个主模块**  
- 现有 Supabase **登录拦截**逻辑不得破坏  
- 现有聊天 **unread badge** 不得丢失  
- 现有 **Create Game** 流程需保留可用  

### 2.2 代码组织原则

请逐步将代码从 `main.dart` 拆出，按 **feature-first** 方式组织：

```text
lib/
  app/
    app.dart
    router/
    shell/
  core/
    constants/
    theme/
    utils/
    widgets/
    services/
  features/
    feed/
      data/
      domain/
      presentation/
    swipe/
      data/
      domain/
      presentation/
    create/
      presentation/
    inbox/
      data/
      domain/
      presentation/
    profile/
      data/
      domain/
      presentation/
    games/
      data/
      domain/
      presentation/
    auth/
      data/
      domain/
      presentation/
    notifications/
      data/
      domain/
      presentation/
```

---

## 3. 建议的 Sprint 节奏（文档补充，便于执行）

以下为与上文原则一致的**建议顺序**，具体以产品优先级为准：

| 阶段 | 焦点 | 成功标准 |
|------|------|----------|
| Sprint 0 | 文档 + 目录骨架（无行为变更或仅导出） | `flutter analyze` 通过，主流程不变 |
| Sprint 1 | `app/` + `shell/`：把 `MaterialApp` / `SmeetShell` 迁出 `main.dart` | `main.dart` 仅 `runApp` + `Supabase.initialize` |
| Sprint 2 | 单一 feature 试点（如 `feed`）占位页 + 可选入口 | 不替换现有 Home，可加实验入口或 flag |
| Sprint 3+ | 按产品：Feed 数据、Swipe 扩展、Inbox 整合… | 每 Sprint 一个主模块 |

---

## 4. 变更记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | （填入） | 初版执行规格入库 |
