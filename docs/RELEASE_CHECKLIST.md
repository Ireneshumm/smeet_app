# Smeet — 灰度 / 内测发布清单

面向：**工程收口、发布前烟测、环境侧人工项**。不替代法务 / 商店审核要求。

**入口与对外承诺边界**（Release / 灰度 / Debug、商店可说与不可说）：见 [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md)。

**灰度验收记录模板**（轮次勾选、Blocker 分级、是否发测试用户、执行顺序）：见 [`GREY_ACCEPTANCE_RECORD.md`](./GREY_ACCEPTANCE_RECORD.md)。

## 1. 构建与 Supabase 配置

### 1.1 Release 构建（必须带 dart-define）

`lib/core/config/supabase_env.dart` 规定：

- **`kReleaseMode` 下若未同时设置** `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`，应用会在启动时抛错（避免误发带仓库内嵌密钥的「正式包」）。
- **`kReleaseMode` 下若两值已设置但像文档占位符**（例如 URL 含 `your_project`、`example.com`，或 anon key 过短、非 JWT 形态），应用也会在启动时抛错——请**只使用** Supabase Dashboard → **Settings → API** 中的 **Project URL** 与 **anon public** 整段复制，勿粘贴文档里的 `YOUR_PROJECT` / `YOUR_ANON_JWT` 字样。

示例（**须将值替换为 Dashboard 真实值**；下面仅为命令格式）：

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9......
```

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9......
```

- **人工 / CI**：在 Xcode Archive、Play 内测流水线、Codemagic 等中同步传入相同 `--dart-define`（或等价注入方式）。
- **密钥轮换**：若仓库曾公开且内含 dev fallback anon key，应在 Supabase 控制台轮换 anon key，并仅通过 CI 密钥库注入新值。

### 1.2 Debug / Profile（本地开发）

未传 `dart-define` 时，**非 release** 构建会使用 `supabase_env.dart` 中的 **dev fallback**（与历史 `main.dart` 硬编码一致），便于 `flutter run`。

- 若仅使用自有 dev 项目，可将 fallback 改为你的 dev URL/key（仍勿当作生产最终形态）。

### 1.3 无法在本仓库内完成的事项（需人工）

| 项 | 说明 |
|----|------|
| Supabase 项目 / RLS / 表 | 确认 `matches`、`swipes`、`profiles`、`games`、`chats`、`messages` 等与客户端假设一致 |
| Auth 重定向 URL | Web 或邮箱验证：在 Supabase Dashboard → Authentication → URL Configuration 配置 |
| 商店签名、Provisioning、隐私问卷 | 按 Apple / Google 流程完成 |
| 法务定稿 | `lib/legal/` 等文案需 counsel 批准后再对外承诺 |

---

## 2. Release 与 Debug 行为收口（代码层）

产品视角的入口清单与商店口径见 [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md)。

| 行为 | Debug / Profile | Release |
|------|-----------------|---------|
| MVP Debug FAB（虫图标） | `kDebugMode` 时显示 | **不显示** |
| 命名路由（Feed / Inbox / Create hub / Notifications / Profile MVP / Setup demo） | 已注册，可从 FAB 进入 | **`MaterialApp.routes` 为空**，`pushNamed` 到这些路径会失败 |
| Feed 默认数据源 | 不变（仍为 `FeedListDataSource.supabase`）；Mock 仅在有对应路由的构建中可从 UI 切换 | Release 无 Feed 路由，用户无法从应用内打开 Feed MVP 页 |
| Create Note / Video 成功后跳转 | `MaterialPageRoute` → `ProfileMvpPage`（不依赖命名路由），从 Create hub 进入时仍可用 | Release 无 Create hub 路由时，**无法从应用内进入 Create MVP**；发帖可走 **底栏 Profile** 等既有路径 |

**灰度建议**：若内测员**必须**在 **release 包**里使用 Feed / Inbox / Create hub，需单独增加「内测 flavor」或 `dart-define` 开关注册路由（当前仓库未实现，属后续任务）。

---

## 3. 发布前烟测清单（可勾选）

在**目标环境**（与生产一致的 Supabase 项目）执行。建议 **release + dart-define** 与 **debug** 各跑一轮关键路径。

### 3.1 账号

- [ ] 新用户 **注册**（邮箱/所用方式）
- [ ] **登录**、登出后再登录
- [ ] Web（若发 Web）：登录 / 回调 URL 无报错

### 3.2 Profile

- [ ] 首次登录无 `profiles` 行时，Shell 是否引导到 **Profile** 并完成必填项
- [ ] 保存资料（姓名、城市、简介、运动等）后重启 App 仍一致
- [ ] 头像上传（若启用）

### 3.3 组局

- [ ] **创建局**（Home 流程）：填写时间、地点、人数等并成功写入
- [ ] 列表中出现该局
- [ ] **加入局**；My Game / 参与者状态正确

### 3.4 Swipe / Match

- [ ] 登录用户 **Like / Pass** 写入正常
- [ ] 双方互 Like 后出现 **Match**，且能进入 **聊天**（与当前客户端逻辑一致）
- [ ] `MatchesPage` 或 Inbox Matches（**debug 有路由时**）列表与预期一致

### 3.5 聊天

- [ ] 底栏 **Chat** 列表加载
- [ ] 进入 **ChatRoom**，收发明细消息
- [ ] 未读角标大致合理（已知与 Inbox 快照存在边界，见历史结论）

### 3.6 发帖（Note / Video）

- [ ] 在 **底栏 Profile** 或 **Create MVP（debug）** 发 **文字 note**，Posts 列表可见
- [ ] 上传 **视频帖**（时长/大小限制符合预期），Posts 可见

### 3.7 Release 专项

- [ ] **无** MVP Debug FAB
- [ ] `flutter build ... --release` **未**传 dart-define 时 **应启动失败**（符合预期）
- [ ] 传齐 dart-define 的 release 包可正常启动并连上 Supabase

---

## 4. 分析与健康检查

```bash
dart analyze
```

发布前应在 CI 或本地执行，**无 error**（info 级 deprecation 可分期处理）。

---

## 5. 灰度发布适合性（工程视角）

在以下条件满足时，从**工程与配置**角度可支持 **灰度 / 内测**：

1. Release 构建 **始终** 注入 `SUPABASE_URL` / `SUPABASE_ANON_KEY`。
2. 烟测清单在目标 Supabase 环境通过。
3. 产品侧已接受：Release 包**不**含 Feed / Inbox / Notifications / Create hub / Profile MVP 的**命名路由入口**（主路径为 Shell 五 Tab + Profile 内功能）。

若不满足 3，需增加内测 flavor 或 define 开关后再灰度。与「灰度包是否额外开放路由」的对照说明见 [`RELEASE_AND_GREY_SCOPE.md` §2](./RELEASE_AND_GREY_SCOPE.md)。
