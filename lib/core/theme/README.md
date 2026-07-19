# Smeet 设计规范 (Design Tokens)

统一间距、字号、图标、圆角、颜色的单一来源。新代码一律引用这里的 token，
不要再手写魔法数字。

```dart
import 'package:smeet_app/core/theme/theme.dart';
```

## 有哪些 token

| 文件 | 类 | 用途 |
|------|------|------|
| `app_colors.dart` | `AppColors` | 品牌色（`SmeetApp.smeetXxx` 现在只是它的别名） |
| `app_spacing.dart` | `AppSpacing` | 间距 `xxs4 / xs8 / sm12 / md16 / lg20 / xl24 / xxl32 / xxxl40` |
| `app_icon_size.dart` | `AppIconSize` | 图标 `xs16 / sm20 / md24 / lg32 / xl40 / xxl48` |
| `app_radius.dart` | `AppRadius` | 圆角 `sm8 / md12 / lg18 / xl24 / pill` |
| `app_text_theme.dart` | `buildSmeetTextTheme()` | 完整字号 ramp，已接入 `ThemeData` |

## 字号：优先用 textTheme，不要手写 fontSize

之前只定义了 5 个文字样式，其余（`bodyMedium`、`titleSmall`、`labelSmall`、
headline 系列…）全部退回 Material 默认，这是各屏幕字号不一致的根因。现在整套
ramp 已定义。**新代码用语义样式**：

```dart
// ✅ 推荐
Text('标题', style: Theme.of(context).textTheme.titleMedium);
Text('正文', style: Theme.of(context).textTheme.bodyMedium);
Text('说明', style: Theme.of(context).textTheme.bodySmall);

// ❌ 避免
Text('标题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
```

对照表（把硬编码 fontSize 映射到语义样式）：

| 硬编码 fontSize | 用哪个 textTheme |
|---|---|
| 24 | `displaySmall` / `headlineSmall` |
| 20 | `titleLarge` / `headlineSmall` |
| 16 | `titleMedium` |
| 14 | `titleSmall`(强调) / `bodyLarge` / `bodyMedium` |
| 12 | `bodySmall` / `labelMedium` |
| 9–11 | `labelSmall`（下限 11，勿再低） |

> ⚠️ 可读性下限：正文类文字不要低于 12，附属 meta 标签不要低于 11。
> 现存 `fontSize: 9/10` 的地方需逐步替换（详见下方迁移清单）。

## 图标：用 AppIconSize

```dart
Icon(Icons.favorite, size: AppIconSize.md);   // ✅ 24
Icon(Icons.close, size: 23);                   // ❌ 魔法数字
```

## 待迁移清单（增量进行，每次改完本地跑 `flutter analyze`）

- [ ] 把 `TextStyle(fontSize: N, ...)` 逐屏替换为 `textTheme.*`（约 25 种散值）
- [ ] 把 `Icon(..., size: N)` 收敛到 `AppIconSize.*`（约 25 种散值）
- [ ] 修复 `fontSize: 9 / 10` 的可读性问题（导航标签、feed、inbox 等）
- [ ] 把硬编码 `EdgeInsets` / `SizedBox` 间距换成 `AppSpacing.*`
- [ ] 把 `BorderRadius.circular(N)` 换成 `AppRadius.*`
