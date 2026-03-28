# 目标 Supabase 环境 — Retention migration 与五项手测记录

本文档用于在**目标 Supabase 项目**上记录：migration 是否已执行，以及五项 retention 能力的手测结论。  
**说明**：仓库内无法代连你的生产/灰度库；下表「手测结果」须由你在目标环境填完。

**逐步执行脚本**（前置、造数、点击路径、预期、分层排查、关键文件）：见 [`RETENTION_HANDTEST_SCRIPT.md`](./RETENTION_HANDTEST_SCRIPT.md)。

---

## 目标 Supabase migration 核对步骤

在 **Dashboard → SQL Editor** 用 **postgres / service role** 执行下列查询（只读即可）。若你在本机用 **Supabase CLI** 链到同一项目，也可在终端核对。

### A. 如何确认 `20260328120000_retention_systems.sql` 已执行

**含义**：脚本可能通过 `supabase db push` 应用（会写迁移表），也可能只在 SQL Editor **手工执行**（未必有迁移表记录）。两种都算「已生效」，以 **B/C/D 对象存在** 为最终依据。

1. **若使用 CLI 管理 migration**（推荐），在项目目录执行：

   ```bash
   supabase migration list
   ```

   输出中应出现 **`20260328120000`**（或与你文件名时间戳一致的一行），且远端标记为已应用（具体列名以当前 CLI 版本为准）。

2. **查迁移表**（仅当项目启用了 `supabase_migrations` 且由 CLI 推过）：

   ```sql
   SELECT version, name
   FROM supabase_migrations.schema_migrations
   WHERE version = '20260328120000'
      OR name LIKE '%20260328120000%'
      OR name LIKE '%retention_systems%';
   ```

   - **有行**：可记录为「CLI/迁移链已登记」。  
   - **无行**：仍可能是 **纯 SQL Editor 执行** → 继续做完 **B～E**；只要对象齐全即视为已执行。

---

### B. 如何确认 `user_notifications` 表存在

```sql
SELECT c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname = 'user_notifications';
```

- **预期**：返回 **一行** `user_notifications`。

**可选（列级）**：

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'user_notifications'
ORDER BY ordinal_position;
```

应至少含：`id`, `user_id`, `actor_user_id`, `type`, `entity_type`, `entity_id`, `payload`, `is_read`, `created_at`（与仓库 migration 一致）。

---

### C. 如何确认 `trg_notify_swipe_like` / `trg_notify_match` 存在

仓库里的命名关系要分清：

| 数据库对象 | 名称 |
|------------|------|
| **函数** | `public.trg_notify_swipe_like()`、`public.trg_notify_match()` |
| **触发器（挂在表上）** | `trg_swipes_like_notify` → 表 `public.swipes`；`trg_matches_notify` → 表 `public.matches` |

**1）函数是否存在**

```sql
SELECT p.proname AS function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('trg_notify_swipe_like', 'trg_notify_match');
```

- **预期**：**两行**（两个函数名各出现一次）。

**2）触发器是否挂在正确表上**

```sql
SELECT t.tgname AS trigger_name,
       t.tgrelid::regclass AS on_table
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname = 'public'
  AND t.tgname IN ('trg_swipes_like_notify', 'trg_matches_notify');
```

- **预期**：两行 — `trg_swipes_like_notify` on `swipes`，`trg_matches_notify` on `matches`。

---

### D. 如何确认 `create_game_event_notification` / `get_identity_stats` 存在

```sql
SELECT p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('create_game_event_notification', 'get_identity_stats');
```

- **预期**：两行。  
  - `create_game_event_notification` 参数应为 `(p_type text, p_game_id uuid, p_payload jsonb)`（或等价签名）。  
  - `get_identity_stats` 应为 `(p_user_id uuid)`，返回 `jsonb`。

**确认 authenticated 可调用**（与 migration 中 `GRANT` 一致）：

```sql
SELECT has_function_privilege('authenticated', 'public.create_game_event_notification(text,uuid,jsonb)', 'EXECUTE') AS anon_can_exec_create_notif,
       has_function_privilege('authenticated', 'public.get_identity_stats(uuid)', 'EXECUTE') AS anon_can_exec_identity;
```

（若 `has_function_privilege` 的签名与库中不完全一致，以 `\df+ public.create_game_event_notification` 在 psql 中看到的为准；Dashboard 也可用 **Database → Functions** 目视确认。）

---

### E. 如何确认 `user_notifications` 已进入 Realtime publication

Supabase 默认使用 publication 名 **`supabase_realtime`**（若项目改过名，以 Dashboard 为准）。

**SQL**

```sql
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename = 'user_notifications';
```

- **预期**：**至少一行**（`supabase_realtime` + `public` + `user_notifications`）。

**Dashboard 路径（与 SQL 等价）**

1. **Database → Publications** → 打开 **`supabase_realtime`**。  
2. 在表列表中确认包含 **`public.user_notifications`**。

若 SQL 无行、但 migration 里执行过 `ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications`，可 **在 SQL Editor 再执行一次**（需足够权限）：

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications;
```

（若已加入会报错 *already member*，也可反证已存在——以 `pg_publication_tables` 查询为准。）

---

### 核对清单（可打勾）

| 检查项 | 通过 |
|--------|------|
| A. `schema_migrations` 或 `supabase migration list` 显示 `20260328120000`（可选；手工 SQL 可无） | ☐ |
| B. 表 `public.user_notifications` 存在 | ☐ |
| C. 函数 `trg_notify_swipe_like`、`trg_notify_match` + 触发器 `trg_swipes_like_notify`、`trg_matches_notify` | ☐ |
| D. 函数 `create_game_event_notification`、`get_identity_stats` 存在且可授权给 `authenticated` | ☐ |
| E. `user_notifications` ∈ `supabase_realtime` publication | ☐ |

---

## 1. Migration 执行

| 项 | 内容 |
|----|------|
| **脚本文件** | `supabase/migrations/20260328120000_retention_systems.sql` |
| **建议命令** | `supabase db push`（CLI 已链项目时）或在 Dashboard → SQL Editor **整段执行** 该文件 |
| **依赖** | 已有 `public.swipes`、`public.matches`、`public.games`、`public.game_participants`、`public.profiles` 等与现有 MVP 一致 |
| **Realtime（可选核对）** | Dashboard → Database → Replication：`user_notifications` 应在 publication 中（脚本内已尝试 `ALTER PUBLICATION`） |

| 执行状态 | 填写 |
|----------|------|
| 已在目标环境执行 | ☐ 是 ☐ 否 |
| 执行日期 | |
| 操作人 | |
| 备注（报错/回滚等） | |

---

## 2. 五项手测结果（仅汇报以下 5 项）

**判定**：Pass / Fail / Blocked（环境或数据不满足） / 跳过

| # | 验收项 | 通过标准（摘要） | 手测结果 | 备注 |
|---|--------|------------------|----------|------|
| 1 | **incoming_like** | 用户 A 对 B `like`，且尚未 mutual：B 的 `user_notifications` 出现 `type = incoming_like`；客户端 Shell 角标或列表可见 | **待填** | 依赖 §1 migration；触发器 `trg_notify_swipe_like` |
| 2 | **like back → match + 直聊** | B 回 like 后：存在 `matches` 行；客户端能进入双方 `chats`/`chat_members` 直聊；与既有流程一致 | **待填** | 相关 `incoming_like` 应被标读（触发器 `trg_notify_match` + 客户端） |
| 3 | **game_last_spot** | 已加入局且 `players - joined_count = 1`：客户端轮询 RPC 后，出现 `game_last_spot` 通知（或 RPC 去重后仅一条） | **待填** | `GameEventNotificationService` + `create_game_event_notification` |
| 4 | **game_starting_soon** | 已加入局且开赛时间在约 **30 分钟内**：出现 `game_starting_soon`（当前实现为 ≤30m 窗口） | **待填** | 同上；需造局时间满足条件 |
| 5 | **profile identity** | 自己 Profile（及可选他人 Profile）展示 `get_identity_stats` 统计与徽章；无报错或空白异常 | **待填** | RPC `get_identity_stats`；UI `ProfileIdentitySection` |

---

## 3. 本仓库侧说明（非手测结论）

- 以上五项**未在 Cursor/CI 内对真实 Supabase 执行**；本文件仅提供**结构与通过标准**。  
- 填完 §1、§2 后，可作为灰度/发布附件或 `GREY_ACCEPTANCE_RECORD.md` 的引用材料。
