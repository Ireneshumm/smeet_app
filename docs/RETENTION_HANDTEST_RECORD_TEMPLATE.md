# Retention 手测 — 执行记录模板

测试员逐项填写；每项判定 **Pass / Fail / Blocked**，并记录现象、证据与初步怀疑层级。

**怀疑层级（单选或多选）**：`SQL`（表/触发器/数据） · `RPC`（Postgres 函数） · `Realtime`（publication/订阅） · `UI`（客户端界面/角标/路由） · `RLS`（策略/权限）

---

## 环境与构建（整次测试共用）

| 字段 | 填写 |
|------|------|
| 日期 | |
| 测试员 | |
| 包类型 | ☐ Debug ☐ Release |
| Supabase 项目 | ☐ dev ☐ staging ☐ prod |
| Migration `20260328120000` | ☐ 已执行 ☐ 未执行 |
| Realtime（`user_notifications`） | ☐ 已确认 ☐ 未确认 |
| 构建命令 / CI 任务（可打码） | |

---

## 1. incoming_like

| 字段 | 填写 |
|------|------|
| **结果** | ☐ Pass ☐ Fail ☐ Blocked |
| **实际现象** | |
| **截图 / 日志** | （附件路径或链接） |
| **初步怀疑层级** | ☐ SQL ☐ RPC ☐ Realtime ☐ UI ☐ RLS ☐ 无 / 不确定 |
| **备注** | |

---

## 2. like back → match + 直聊

| 字段 | 填写 |
|------|------|
| **结果** | ☐ Pass ☐ Fail ☐ Blocked |
| **实际现象** | |
| **截图 / 日志** | |
| **初步怀疑层级** | ☐ SQL ☐ RPC ☐ Realtime ☐ UI ☐ RLS ☐ 无 / 不确定 |
| **备注** | |

---

## 3. game_last_spot

| 字段 | 填写 |
|------|------|
| **结果** | ☐ Pass ☐ Fail ☐ Blocked |
| **实际现象** | |
| **截图 / 日志** | |
| **初步怀疑层级** | ☐ SQL ☐ RPC ☐ Realtime ☐ UI ☐ RLS ☐ 无 / 不确定 |
| **备注** | |

---

## 4. game_starting_soon

| 字段 | 填写 |
|------|------|
| **结果** | ☐ Pass ☐ Fail ☐ Blocked |
| **实际现象** | |
| **截图 / 日志** | |
| **初步怀疑层级** | ☐ SQL ☐ RPC ☐ Realtime ☐ UI ☐ RLS ☐ 无 / 不确定 |
| **备注** | |

---

## 5. profile identity

| 字段 | 填写 |
|------|------|
| **结果** | ☐ Pass ☐ Fail ☐ Blocked |
| **实际现象** | |
| **截图 / 日志** | |
| **初步怀疑层级** | ☐ SQL ☐ RPC ☐ Realtime ☐ UI ☐ RLS ☐ 无 / 不确定 |
| **备注** | |

---

## 汇总

| 项 | 结果 |
|----|------|
| 1. incoming_like | |
| 2. like back → match + 直聊 | |
| 3. game_last_spot | |
| 4. game_starting_soon | |
| 5. profile identity | |

**其他阻塞项**（无则写「无」）：

**整次结论**（测试员勾选）： ☐ 可进入灰度 ☐ 有条件 ☐ 不可 ☐ 仅记录、不判灰度

**签字 / 日期**：

---

**执行步骤说明**：见 [`RETENTION_HANDTEST_SCRIPT.md`](./RETENTION_HANDTEST_SCRIPT.md)。**Migration 核对**：见 [`SUPABASE_RETENTION_HANDTEST.md`](./SUPABASE_RETENTION_HANDTEST.md)。
