# Smeet — 灰度验收记录（模板 + 决策清单）

面向：**单次灰度轮次**的验收勾选、问题分级、放行决策。  
**不替代** [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) 的工程步骤与 [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md) 的入口/承诺边界。

| 文档 | 用途 |
|------|------|
| [`RELEASE_CHECKLIST.md`](./RELEASE_CHECKLIST.md) | 构建 `dart-define`、Release/Debug 差异、烟测条目 |
| [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md) | Release 可见入口、灰度与商店口径、Chat vs Inbox |

---

## 一、灰度轮次元数据（每轮复制本节填空）

| 字段 | 填写 |
|------|------|
| 轮次编号 / 日期 | |
| 构建类型 | 例：`release` + `SUPABASE_URL` / `SUPABASE_ANON_KEY` |
| 平台 | Android / iOS / 二者 |
| 构建号 / Git SHA | |
| 目标 Supabase 项目 | dev / staging / prod（与密钥一致） |
| 验收人 | |
| 分发渠道 | TestFlight / Play 内测 / APK 直发 等 |

**本包构建形态（与边界文档对齐）**

- [ ] 与 [`RELEASE_AND_GREY_SCOPE.md` §1](./RELEASE_AND_GREY_SCOPE.md) 一致：主路径为 **Shell 五 Tab**，无 Feed / Inbox / Create hub 等 **命名路由**（除非单独发了含 flavor 的包 — 见 [`RELEASE_AND_GREY_SCOPE.md` §2](./RELEASE_AND_GREY_SCOPE.md)）。
- [ ] 无 MVP Debug FAB（Release 预期）。

---

## 二、判定规则：Blocker / 非 Blocker / 人工确认

### 2.1 Blocker（阻断灰度扩大或商店上架）

满足 **任一** 即视为 blocker，须在下一轮构建前修复或明确「本轮仅限极小范围技术灰度」：

- **无法完成主链路**：注册/登录、Profile 必填、创建/加入局、Swipe→Match→进入 ChatRoom、Chat 收发、在 **Release 可达路径** 下的发帖（见下表「路径说明」）之一 **系统性失败**（非偶发网络）。
- **数据与安全**：误用错误 Supabase 项目、RLS 明显敞开导致跨用户数据可见、密钥泄露或构建未注入 `dart-define` 却仍能启动（与 [`RELEASE_CHECKLIST.md` §1](./RELEASE_CHECKLIST.md) 预期不符时应追查）。
- **启动即崩溃**、核心 Tab 白屏无法恢复。
- **法务 / 合规红线**：未同意的数据处理、商店必填隐私项缺失（本仓库文档不覆盖具体法务结论）。

### 2.2 非 Blocker（体验项，可记入 backlog）

- 文案笔误、间距、空态不够友好、角标与理想状态略有偏差。
- **已知边界**：如 Chat 未读角标与 Inbox 快照差异（见 [`RELEASE_CHECKLIST.md` §3.5](./RELEASE_CHECKLIST.md)），**不影响**收发消息主路径。
- Release **不包含** 的 MVP 页面（Feed / Inbox 等）的缺失，**不**算 blocker —— 除非对外宣传了该能力（违反 [`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md) 时应先改宣传而非扩功能）。

### 2.3 仍需人工确认项

- 所有下表 **未在本轮目标环境勾选** 的条目。
- **头像上传**、**Web**、**真机推送** 等依赖配置或可选能力的项。
- **双方账号互 Like** 等需两人配合或脚本辅助的场景。

### 2.4 「代码/文档基线」vs「本轮已通过」

- **仓库当前状态**（主链路实现 + 发布硬化 + 近期 polish）支撑 **预期可验收** 的行为；**不代表**已在你的 Supabase 环境跑通。
- 下表中 **「已通过」** 仅在与 **轮次元数据** 一致的环境内 **人工勾选** 后生效；本模板不预填「已生产验证通过」。

---

## 三、主链路验收 Checklist（按环境勾选）

**路径说明（与 Release 边界一致）**

- **发帖**：灰度若为标准 **Release 包**，验收 **底栏 Profile** 路径下的 Note / Video；**Create hub / Profile MVP** 仅在 Debug 或未来内测 flavor 中验收（见 [`RELEASE_AND_GREY_SCOPE.md` §1、§4](./RELEASE_AND_GREY_SCOPE.md)）。
- **Feed**：标准 Release 包 **无应用内 Feed 入口**；若需验 Feed，须 **Debug 构建** 或 **单独内测包**（见 [`RELEASE_AND_GREY_SCOPE.md` §7](./RELEASE_AND_GREY_SCOPE.md)）。下表 Feed 行标注为「视构建形态勾选」。

| # | 链路 | 验收要点 | 本轮结果（勾选） | 备注 / 问题编号 |
|---|------|----------|------------------|-----------------|
| 1 | **注册** | 新用户可完成注册（所用 Auth 方式与 [`RELEASE_CHECKLIST.md` §1.3](./RELEASE_CHECKLIST.md) 配置一致） | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 2 | **登录** | 登录、登出再登录 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 3 | **Profile 创建 / 保存** | 无 `profiles` 行时引导补全；保存后重启一致 | ☐ 通过 ☐ 失败 ☐ 未测 | 头像若启用则单独验 |
| 4 | **Create Game** | Home 流程创建局，列表可见 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 5 | **Join Game** | 加入局；My Game / 参与者状态正确 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 6 | **Swipe** | Like / Pass 写入正常 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 7 | **Mutual match → ChatRoom** | 互 Like 后出现 Match，可进入聊天 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 8 | **Chat 发消息** | 底栏 Chat 列表、ChatRoom 收发 | ☐ 通过 ☐ 失败 ☐ 未测 | |
| 9 | **Post Note** | **Release 路径**：Profile 发文字，Posts 可见 | ☐ 通过 ☐ 失败 ☐ 未测 ☐ N/A | N/A = 本包无此入口 |
| 10 | **Upload Video** | **Release 路径**：Profile 发视频，Posts 可见 | ☐ 通过 ☐ 失败 ☐ 未测 ☐ N/A | |
| 11 | **Feed 打开 / 刷新** | 仅 **Debug / 内测包**：打开 Feed、下拉刷新、空错态可读 | ☐ 通过 ☐ 失败 ☐ 未测 ☐ N/A | 标准 Release 填 N/A |
| 12 | **Release 专项** | 无 FAB；`dart-define` 缺失时启动失败、传入则可连 Supabase（见 [`RELEASE_CHECKLIST.md` §3.7](./RELEASE_CHECKLIST.md)） | ☐ 通过 ☐ 失败 ☐ 未测 | |

**与 [`RELEASE_CHECKLIST.md` §3](./RELEASE_CHECKLIST.md) 的对应关系**：上表为灰度「决策用」浓缩版；完整烟测仍以该节逐项为准。

---

## 四、问题登记（Blocker / 非 Blocker）

| ID | 描述 | 复现步骤 | 分级 | 责任人 | 状态 |
|----|------|----------|------|--------|------|
| G-001 | | | Blocker / 非 Blocker | | Open / Fixed / Won’t fix |

---

## 五、是否建议发给测试用户 — 判断标准

**建议发放**（满足全部）：

1. **构建正确**：目标平台 **release**（或明确告知测试者的 debug 范围）且 Supabase 注入与 **轮次环境** 一致（[`RELEASE_CHECKLIST.md` §1](./RELEASE_CHECKLIST.md)）。
2. **无未关闭 Blocker** 落在 §三 中 **你本轮承诺要测的主链路** 上（例如若本轮只测社交不测组局，须在招募说明中写清）。
3. **预期对齐**：测试者已知 **当前包不含** Feed / Inbox / 通知中心等（若为标准 Release），避免期望落差（[`RELEASE_AND_GREY_SCOPE.md`](./RELEASE_AND_GREY_SCOPE.md)）。
4. **反馈渠道明确**：表单 / 群 / Issue 模板任选其一，并约定日志或录屏是否需提供。

**不建议发放**（满足任一）：

- 存在 §2.1 类 Blocker 且未修复、未在招募中降级说明。
- 密钥或环境混用（staging 包连 prod 等）。
- 对外宣传超出 [`RELEASE_AND_GREY_SCOPE.md` §4–§5](./RELEASE_AND_GREY_SCOPE.md) 可承诺范围。

---

## 六、灰度执行顺序（推荐）

1. **打包**  
   - 按 [`RELEASE_CHECKLIST.md` §1](./RELEASE_CHECKLIST.md) 执行 `flutter build … --release` 并注入 `dart-define`；记录 **Git SHA** 与版本号。  
   - 本地或 CI 跑 `dart analyze`（[`RELEASE_CHECKLIST.md` §4](./RELEASE_CHECKLIST.md)）。

2. **分发**  
   - 上传 TestFlight / Play 内测或受控 APK；**仅向知情用户**分发，并附 **本轮范围说明**（见 §五、§三路径说明）。

3. **测试反馈收集**  
   - 使用 §四 表格或等价工具汇总；区分 Blocker / 非 Blocker。  
   - 对「无法复现」项要求环境信息（系统版本、构建号、账号类型）。

4. **Blocker 修复**  
   - 仅合入修复 **blocker** 的变更（本任务包不要求扩功能）；修复后 **递增构建号** 并重复 §六 1–3。  
   - 非 Blocker 进入 backlog，不阻塞下一轮扩大灰度 **除非** 产品另有要求。

---

## 七、本轮决策结论（签字栏）

| 结论 | 勾选 |
|------|------|
| 同意扩大灰度 / 进入下一分发阶段 | ☐ |
| 维持当前范围，仅修 Blocker 后再发 | ☐ |
| 暂停灰度（列明原因） | ☐ |

**决策人 / 日期**：________________

---

## 八、人工补充清单（本模板无法代填）

- 实际 **Supabase 项目** 与 **Auth 方式**（邮箱 / OAuth / 等）。
- **测试账号** 准备（单用户 / 双用户 Match）。
- **商店 / 法务** 是否已审阅对外说明（本仓库 `lib/legal/` 与 counsel）。
- **本轮是否使用非标准包**（含 MVP 路由的 flavor）：若是，须在 §一 与 §五 中写清，并与商店包区分。
