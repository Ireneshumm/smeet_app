# Retention 五项 — 逐步手测执行脚本

面向：**目标 Supabase 已应用** `supabase/migrations/20260328120000_retention_systems.sql` 后的联调。  
每步可配合 `docs/SUPABASE_RETENTION_HANDTEST.md` 记录 Pass/Fail。

---

## 通用前置（五项开始前）

| 项 | 说明 |
|----|------|
| **构建** | Debug 或 Release（带 `SUPABASE_URL` / `SUPABASE_ANON_KEY` 指向**目标库**） |
| **账号** | 至少 **2 个**可登录账号（记为 **用户 A**、**用户 B**），邮箱/密码已知 |
| **资料** | A、B 均有 `profiles` 行（能进 Swipe 候选池；若库中人数少，可临时放宽筛选或只测互滑） |
| **工具** | Supabase Dashboard：**Table Editor** / **SQL Editor**；可选浏览器 Network 看 REST 是否 401/403 |

---

## 1. incoming_like

### 前置准备

- Migration 已部署：`user_notifications` 表存在；`trg_swipes_like_notify` 在 `public.swipes` 上。
- B 当前 **没有** 对 A 的 `like`（否则一滑就成 mutual，不会走单向 incoming）。
- 建议先查库确认无互赞：  
  `select * from swipes where (from_user=A and to_user=B) or (from_user=B and to_user=A);`

### 如何造测试数据

1. 用 **用户 A** 登录 App。  
2. 在 **Swipe** 划到 **用户 B**（若刷不到：在 SQL 里确认 B 的 `profiles` 存在；或临时用 SQL 插入一条 `swipes` **仅用于负向**测试时注意不要污染——**推荐全程用 App 点 Like**）。  
3. 点击 **Like**。  
4. **不要**用 B 在 A 之前已 Like A（保持单向）。

（可选 SQL 复核，在 A Like 之后执行：）

```sql
select id, type, user_id, actor_user_id, is_read
from user_notifications
where user_id = '<B的uuid>' and type = 'incoming_like';
```

### App 端点击路径

1. A 登录 → 底栏 **Swipe** → 对 B **Like**。  
2. 退出或切账号前，可先不关 App。  
3. **用户 B** 登录 → 看底栏 **Shell 顶栏铃铛** 未读角标（若有）。  
4. B → 顶栏 **Likes you**（仅当当前 Tab 为 **Swipe** 时显示）或打开 **铃铛 → Notifications** 列表，查找 incoming 类文案。

### 预期结果

- DB：`user_notifications` 中 **B** 有一条 `type = 'incoming_like'`，`actor_user_id = A`，`is_read = false`（初始）。  
- App：B 侧 **incoming_like 未读计数** 或通知列表能体现（`UserNotificationsRepository` / 角标 `smeetIncomingLikesCount`）。

### 失败时先检查哪一层

| 顺序 | 层 | 查什么 |
|------|----|--------|
| 1 | **SQL / 触发器** | `swipes` 是否真有 `action='like'`、`from_user=A`、`to_user=B`；触发器是否启用；若 B 已 like A，触发器会**不插** incoming |
| 2 | **RLS** | 用 B 的 JWT 在 Dashboard 或客户端 `select`：`user_notifications` 是否对 `user_id=B` 可见 |
| 3 | **UI** | `refreshAppNotificationBadges()` 是否被调用；Shell 是否已 `_bindRetentionStreams`（登录后） |
| 4 | **Realtime** | 非必须：角标依赖 `watchMine`+轮询刷新；无 Realtime 也应能下次 `fetch` 看到 |

### 对应关键文件

- `supabase/migrations/20260328120000_retention_systems.sql` — `trg_notify_swipe_like`、`uq_user_notifications_incoming_like`  
- `lib/core/services/user_notifications_repository.dart` — `countUnreadIncomingLikes`、`fetchRecent`  
- `lib/core/services/app_notification_badges.dart` — `smeetIncomingLikesCount`  
- `lib/app/shell/smeet_shell.dart` — `_bindRetentionStreams`、`watchMine`  
- `lib/main.dart` — `SwipePage._swipe`（写入 `swipes`）

---

## 2. like back → match + 直聊

### 前置准备

- 已完成 **§1**，即 B 已有 `incoming_like`（或等价：双方尚未 `matches`，但 A 已 like B）。  
- 清楚 **B 的账号**用于回赞。

### 如何造测试数据

**路径 A（推荐）**：在 §1 基础上，**B 登录** → 对 A **Like back**（二选一）：

- **Likes you** 列表里点 **Like back**，或  
- **Swipe** 划到 A 点 **Like**（若仍出现 A）。

**路径 B（SQL 仅校验，不替代 App）**：Like back 成功后应有：

```sql
select * from matches where user_a in ('<A>','<B>') and user_b in ('<A>','<B>');
select id from chats order by created_at desc limit 1; -- 视客户端插入顺序而定
```

### App 端点击路径

1. **B** 登录。  
2. 底栏 **Swipe** → 顶栏 **Likes you** → 选 A → **Like back**（`lib/main.dart` `LikesYouPage`）。  
   或 Swipe 卡片对 A Like。  
3. 若弹出/进入 **ChatRoom**：即直聊创建成功。  
4. 若从 celebration 返回，底栏 **Chat** 应出现与 A 的会话。

### 预期结果

- DB：`matches` 有规范化 `(user_a, user_b)`；`chats` + `chat_members` 含 A、B。  
- `user_notifications`：相关 `incoming_like` 被标 **`is_read = true`**（`trg_notify_match`）；双方可有 `mutual_match` 行。  
- App：能进入 **直聊** 发消息。

### 失败时先检查哪一层

| 顺序 | 层 | 查什么 |
|------|----|--------|
| 1 | **UI / 客户端逻辑** | `LikesYouPage._likeBack` / `SwipePage._swipe` 是否报错；是否重复插入 `chats` 导致唯一约束 |
| 2 | **SQL** | `matches` 是否插入成功；`swipes` 双方是否均为 `like` |
| 3 | **触发器** | `trg_notify_match` 是否在 `matches` insert 后执行；`incoming_like` 是否更新 |
| 4 | **RLS** | `chat_members` / `messages` 是否允许双方读写 |
| 5 | **Realtime** | 聊天列表不依赖 `user_notifications` Realtime |

### 对应关键文件

- `lib/main.dart` — `LikesYouPage._likeBack`、`SwipePage._swipe`（`matches`、`chats`、`chat_members`）  
- `supabase/migrations/20260328120000_retention_systems.sql` — `trg_notify_match`  
- `lib/core/services/user_notifications_repository.dart` — `markIncomingLikesFromUserRead`

---

## 3. game_last_spot

### 前置准备

- 存在一个 **game**，字段满足：`players`（容量）− `joined_count`（已加入）**= 1**，且 `players > 0`。  
- **当前登录用户** 已在 `game_participants` 中 **`status = 'joined'`** 且 `game_id` 指向该局（否则 RPC 拒绝）。  
- App **已打开且在前台**至少等到 **~60 秒**（Shell 内 `Timer.periodic` + 首次 `runChecksForJoinedGames`）。

### 如何造测试数据

**用 SQL 造局（示例，按你表结构调字段名）：**

```sql
-- 示例思路：设 players=3, joined_count=2，则 remaining=1 → last_spot
-- 具体列名以 public.games 为准（常见：id, players, joined_count, starts_at, ends_at）
update games
set players = 3, joined_count = 2, starts_at = now() + interval '2 hours'
where id = '<game_uuid>';
```

确保 **测试用户** 是该局 `game_participants` 中一名 **joined** 用户。  
若 `joined_count` 由触发器维护，应通过 **加入/退出** 或后台一致地改，避免与真实人数不一致。

### App 端点击路径

1. 使用 **已加入该局** 的账号登录。  
2. 保持 App **前台** ≥ **1 分钟**（或冷启动后等待定时器）。  
3. 打开 **Shell 顶栏铃铛** → **Notifications**，查看是否出现 **Last spot** 类条目（文案见 `notifications_page.dart` 映射）。

### 预期结果

- DB：`user_notifications` 中 **当前用户** 一条 `type = 'game_last_spot'`，`entity_id = game_id`；重复点击不产生重复（唯一索引 + RPC 内 `EXISTS`）。  
- App：列表或角标更新（依赖 `refreshAppNotificationBadges` / `watchMine`）。

### 失败时先检查哪一层

| 顺序 | 层 | 查什么 |
|------|----|--------|
| 1 | **数据** | `games` 行：`players - joined_count` 是否 **等于 1**；`joinedLocal` 是否包含该 `game_id`（Shell `_syncJoinedFromDb`） |
| 2 | **RPC** | `create_game_event_notification('game_last_spot', game_id, …)` 是否返回错误（NOT_PARTICIPANT / INVALID_TYPE） |
| 3 | **客户端** | `lib/core/services/game_event_notification_service.dart` 是否调用 `_tryInsert`；日志 `[GameEventNotificationService]` |
| 4 | **RLS** | `user_notifications` 当前用户是否可 `select` 新行 |
| 5 | **UI** | 是否未登录、Shell 未绑定 stream |

### 对应关键文件

- `lib/core/services/game_event_notification_service.dart` — `remaining == 1`  
- `lib/app/shell/smeet_shell.dart` — `Timer.periodic` + `runChecksForJoinedGames`  
- `supabase/migrations/20260328120000_retention_systems.sql` — `create_game_event_notification`、`uq_user_notifications_game_event`

---

## 4. game_starting_soon

### 前置准备

- 同一用户 **已 joined** 该局。  
- `starts_at` 在 **未来**，且距 **现在** 在 **(0, 30] 分钟** 内（代码写死为 30 分钟窗口，见下）。  
- 前台等待定时器触发（同上，约 60s 一轮）。

### 如何造测试数据

将目标局的 `starts_at` 设为 **当前时间 + 15～25 分钟**（示例）：

```sql
update games
set starts_at = now() + interval '20 minutes'
where id = '<game_uuid>';
```

确保 `ends_at` 若存在，应晚于 `starts_at`；且该局仍满足参与条件。

### App 端点击路径

1. 参与用户登录，保持前台。  
2. 等待 **≥1 分钟**（或杀进程重进触发 `runChecksForJoinedGames`）。  
3. **铃铛 → Notifications** 查看 **Starting soon** 类文案。

### 预期结果

- DB：`type = 'game_starting_soon'`，`payload` 可含 `minutes`；`entity_id` 为 `game_id`。  
- **注意**：若你把开赛时间设在 **30 分钟以外**，按当前实现 **不会** 插入（非 bug，是产品窗口限制）。

### 失败时先检查哪一层

| 顺序 | 层 | 查什么 |
|------|----|--------|
| 1 | **数据** | `starts_at` 是否在 **未来** 且 `now()` 差在 **1～30 分钟**；设备时区与 DB `timestamptz` 是否一致 |
| 2 | **RPC** | 同 §3，`create_game_event_notification` |
| 3 | **客户端** | `game_event_notification_service.dart` 中 `until.inMinutes <= 30 && > 0` |
| 4 | **RLS / UI** | 同 §3 |

### 对应关键文件

- `lib/core/services/game_event_notification_service.dart` — 第 43～48 行（30 分钟逻辑）  
- `lib/app/shell/smeet_shell.dart` — 定时器  
- `supabase/migrations/20260328120000_retention_systems.sql` — `create_game_event_notification`

---

## 5. profile identity

### 前置准备

- Migration 已包含 `get_identity_stats(uuid)` 且 **已 GRANT** 给 `authenticated`。  
- 当前用户已有一定 **game_participants / games / matches** 数据时，统计更直观（全 0 也应不报错）。

### 如何造测试数据

- **自然数据**：参加局、创建局、产生 match（前几步已覆盖）。  
- **SQL 抽检**（仅验证 RPC，不替代 App）：

```sql
select public.get_identity_stats('<user_uuid>'::uuid);
-- 需在 Dashboard 用 service role 或模拟 authenticated；直接 SQL 可能受 `auth.uid()` 限制
```

在客户端，RPC 由已登录用户调用即可。

### App 端点击路径

1. **自己**：登录 → 底栏 **Profile** → 页面中 **「Your sports identity」** 区块（统计 + Badges）。  
2. **他人**（可选）：从任意入口打开 **Other profile** → **「Sports identity」**（`lib/other_profile_page.dart`）。

### 预期结果

- 无持续 Loading/红线；展示 **Joined / Hosted / Players met / Matches / This month** 等数字与 **Badges**  chips。  
- 若 RPC 失败，区块可能为空或仅进度条消失（见 `ProfileIdentitySection`）。

### 失败时先检查哪一层

| 顺序 | 层 | 查什么 |
|------|----|--------|
| 1 | **RPC** | Supabase Logs / 客户端 debug：`get_identity_stats` 是否 `NOT_AUTHENTICATED` 或未部署 |
| 2 | **RLS / 函数** | 函数为 `SECURITY DEFINER`，但若内部查询的表 RLS 过严，可能计数异常（少见） |
| 3 | **UI** | `ProfileIdentityService.fetchStats` 是否 catch 后返回 null |
| 4 | **Realtime** | 与本项无关 |

### 对应关键文件

- `supabase/migrations/20260328120000_retention_systems.sql` — `get_identity_stats`  
- `lib/core/services/profile_identity_service.dart` — `fetchStats`、`computeBadgeLabels`  
- `lib/widgets/profile_identity_section.dart` — UI  
- `lib/main.dart` — 自己 Profile 挂载点  
- `lib/other_profile_page.dart` — 他人 Profile

---

## 附录：五项与失败分层速查

| 项 | 首要查 | 次要查 |
|----|--------|--------|
| incoming_like | Trigger + `swipes` 行 | RLS、角标刷新 |
| like back | 客户端 match/chat 插入 | `matches` 触发器、chat RLS |
| game_last_spot | `players/joined_count` + 参与身份 | RPC、定时器 |
| game_starting_soon | `starts_at` 在 30 分钟内 | 同上 |
| profile identity | RPC 部署与 `auth` | `ProfileIdentityService` 错误日志 |

---

**文档版本**：与仓库 `RETENTION_HANDTEST_SCRIPT.md` 一致；若改 30 分钟窗口或定时器周期，请同步改 §4、§3 与 `game_event_notification_service.dart`。
