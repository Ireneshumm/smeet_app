# Smeet — Release / 灰度 / Debug 发布边界

本文档定义 **用户可见入口**、**商店与对外可承诺范围**，以及 **工程上的构建边界**。  
**不替代** 法务、隐私问卷、商店审核要求；法务定稿仍以 `lib/legal/` 及 counsel 为准。

**相关文档**

- 构建命令、Supabase 注入、烟测勾选：[`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md)
- 灰度轮次验收模板、放行标准与执行顺序：[`GREY_ACCEPTANCE_RECORD.md`](./GREY_ACCEPTANCE_RECORD.md)
- Retention 在目标 Supabase 上的 migration 与五项手测空白表：[`SUPABASE_RETENTION_HANDTEST.md`](./SUPABASE_RETENTION_HANDTEST.md)

---

## 1. 正式 Release 可见入口

以下入口在 **`flutter build … --release`** 且 **已注入** `SUPABASE_URL` / `SUPABASE_ANON_KEY`（见第 8 节）时，对用户可用。

| 区域 | 说明 |
|------|------|
| **Shell 五 Tab** | 由 `SmeetShell` 提供：**Home**（`HomePage`）、**Swipe**（`SwipePage`）、**MyGame**（`MyGamePage`）、**Chat**（`ChatPage`）、**Profile**（`ProfilePage`）。 |
| **Shell 顶栏（已登录）** | `lib/app/shell/smeet_shell.dart`：**通知**（铃铛 → `NotificationsPage`，读取 `user_notifications` 实时列表，非 Mock）、在 **Swipe** Tab 时额外显示 **Likes you**（→ `LikesYouPage`）。依赖目标环境已执行含 `user_notifications` 的 migration 与 RLS。 |
| **认证** | 未登录或需补资料时，由 Shell 阶段机引导至 **Auth** / **Profile** 等（与 `ShellAuthPhase` 一致）。 |
| **从上述页面栈内进入的子页** | 例如 **ChatRoom**、组局创建/详情、**Matches**、**NotificationsPage** / **LikesYouPage** 等，凡通过 `Navigator.push`（含 `MaterialPageRoute`）进入、**不依赖** MVP 命名路由的，均视为正式路径。 |

**Release 下不可通过应用内主 UI 到达的页面**（当前代码：`kReleaseMode` 时 `MaterialApp.routes` 为空）：

- Feed（信息流 MVP）
- Inbox（三 Tab 收件箱 MVP）
- Create hub / 独立 Create MVP 入口（若仅注册在命名路由上）
- Profile MVP（独立路由页）
- Profile Setup demo

（**说明**：应用内 **通知中心** 已从 **Shell 顶栏** 进入，**不依赖** 下述 Debug 命名路由 `NotificationsRoutes.list`。）

详见 [`RELEASE_CHECKLIST.md` §2](./RELEASE_CHECKLIST.md)。

---

## 2. 灰度可见入口（若未来开 Flavor / Define）

**当前仓库**：灰度若使用 **与商店相同的 release 构建产物**，则 **与 §1 完全一致** —— 无额外「灰度专用」入口，除非另行发不同构建。

**若未来增加** 内测 flavor 或 `dart-define` 开关（例如 `ENABLE_MVP_ROUTES`），**可**在灰度包中恢复部分命名路由，使内测员能进入 **Debug 菜单里** 额外注册的 MVP 页，例如：

- Inbox / Feed / Create hub / **Notifications（与 Shell 顶栏同页的命名路由副本，便于 deep link 调试）** / Profile MVP / Setup demo  

**产品/运营注意**：**通知列表** 对正式用户已通过 **Shell 顶栏** 可达（§1）；灰度包若再打开其它 MVP 路由，**商店描述与截图** 仍应按 **正式 release 边界**（§1、§5）撰写，避免用户误以为商店版具备 Feed/Inbox 等入口。

---

## 3. Debug / Internal Only 入口

| 项 | 行为（代码位置：`lib/main.dart`） |
|----|-----------------------------------|
| **MVP Debug FAB** | `showMvpDebugLauncher: kDebugMode` — **仅 Debug** 构建显示虫标；Release **不显示**。 |
| **MVP 启动器菜单项** | Release 下为空列表；非 Release 为 `_kMvpDebugLauncherItems`（可 `pushNamed` 到各 MVP 路由）。 |
| **命名路由注册** | 非 Release：` _smeetNamedRoutesForNonRelease()`；Release：`const <String, WidgetBuilder>{}`。 |

内测截图若含虫标或 MVP 菜单，须标注为 **开发构建**，勿当作商店版界面。

---

## 4. 可对外承诺的功能（与当前实现一致时）

在 **正式 Release 包**（§1）前提下，可对用户/商店描述的**能力**包括（具体文案需产品/法务润色）：

- 账号 **注册 / 登录**（Supabase Auth；Web 需正确配置重定向，见 [`RELEASE_CHECKLIST.md` §1.3](./RELEASE_CHECKLIST.md)）。
- **个人资料**：底栏 Profile 中的编辑、运动偏好等（以 `ProfilePage` 实际能力为准）。
- **组局**：浏览、创建、加入局；**My Game** 与列表状态。
- **Swipe**：喜欢/跳过；**Match** 后与当前客户端一致的 **进入聊天** 流程。
- **Chat**：底栏 Chat 会话列表、**ChatRoom** 收发消息（以当前 Realtime / RLS 为准）。
- **发帖（Note / Video）**：若用户路径为 **底栏 Profile**（或 Shell 内其它**不依赖** MVP 命名路由的入口），可承诺「在 Profile 发帖」；若某版本仅能从 **Create MVP 路由** 进入，则 **Release 下不可承诺**（见 [`RELEASE_CHECKLIST.md` §2](./RELEASE_CHECKLIST.md) 关于 Create 成功跳转的说明）。
- **应用内通知列表**：登录用户可通过 **Shell 顶栏铃铛** 打开 **Notifications**，数据来自 Supabase `user_notifications`（incoming like、match、游戏提醒等）。**系统级推送（APNs/FCM）** 若未接好，仍勿对外承诺「手机推送」。

---

## 5. 不可对外承诺的功能

| 能力 | 原因 |
|------|------|
| **系统推送（后台推送）与完整推送产品** | 应用内列表 ≠ 厂商推送；未接或未验收推送通道前勿承诺。 |
| **Feed 为成熟社交信息流** | Live 数据以局/游戏向为主；Mock 混合内容仅供开发演示。 |
| **Inbox 与底栏 Chat 为双正式入口** | Release 下 **无 Inbox 命名路由**；统一口径见 §6。 |
| **独立 Profile MVP / Setup demo 为正式模块** | 主要为 debug 命名路由场景。 |
| **无配置即可使用** | Release **必须** `--dart-define` 注入 Supabase（§8）。 |

商店素材避免出现 **虚构通知内容、与生产不一致的 Mock 演示、MVP 调试菜单**，除非明确为 **TestFlight / 内测** 且与上架包不一致。（正式包通知列表应为真实 `user_notifications` 数据。）

---

## 6. Chat vs Inbox — 正式口径

- **正式用户入口**：底栏 **Chat**（`ChatPage`）— 会话列表与进入 **ChatRoom**。
- **Inbox**：三 Tab（含 Matches 等）的 MVP 列表；**当前 Release 构建中用户无法从应用内打开**（无注册路由）。  
- **对外表述建议**：写 **「在 Chat 中查看与回复消息」**；勿写「Inbox 已全面开放」除非已发含该路由的构建并更新 §1。

未读角标与 Inbox 快照若存在产品层差异，以 **工程现状 + 产品确认** 为准（烟测见 [`RELEASE_CHECKLIST.md` §3.5](./RELEASE_CHECKLIST.md)）。

---

## 7. Feed / Notifications / MVP — 发布口径

| 模块 | Release | 对外描述建议 |
|------|---------|----------------|
| **Feed** | 无应用内入口（无路由） | 勿作为商店主打能力；若未来开放需单独发版与改 §1。 |
| **Notifications（应用内）** | **有入口**：`SmeetShell` 顶栏铃铛 → `NotificationsPage`，**Live** 读 `user_notifications`；未登录无铃铛逻辑 | 可说 **「应用内通知」**（点赞、匹配、游戏提醒等）；**系统推送** 未就绪则勿承诺 **推送通知**。传入 `repository` 参数的 **纯 Mock 模式** 仅用于测试/Widget 单测，非主路径。 |
| **Create hub / Profile MVP / Setup demo** | Release 无命名路由 | **内部 / 后续迭代**；商店不写为正式功能。 |
| **MVP Debug FAB** | 不存在 | 仅 Debug；勿出现在对外截图。 |

---

## 8. Release 构建与 `dart-define`（必须）

**Supabase**

- `lib/core/config/supabase_env.dart` 中 `resolveSupabaseConfig()`：**`kReleaseMode` 下必须同时设置** `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`**，否则启动抛错**。
- 非 Release 且两者皆空：使用 dev fallback，便于 `flutter run`。

**示例与 CI 要求** 见 [`RELEASE_CHECKLIST.md` §1](./RELEASE_CHECKLIST.md)。

**路由与调试 UI**

- Release：`MaterialApp.routes` 为空；MVP FAB 关闭。行为摘要见 [`RELEASE_CHECKLIST.md` §2](./RELEASE_CHECKLIST.md)。

---

## 文档维护

- 若增加 flavor、命名路由开关或 Shell Tab 变更，应同步更新 **§1–§3** 与 [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) §2、§5。
