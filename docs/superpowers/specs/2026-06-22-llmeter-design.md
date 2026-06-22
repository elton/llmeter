# LLMeter — 设计文档

> 状态：草案 v1，待评审
> 日期：2026-06-22
> 一句话：一个常驻 macOS 菜单栏的原生小工具，一眼掌握各家 AI 订阅套餐的剩余配额与重置时间。v1 支持 **Codex** 与 **Claude**，架构可扩展。开源（**AGPL-3.0**，强 copyleft：含网络/SaaS 场景的衍生版也必须开源，防止被闭源滥用），面向所有用这两个 CLI 的开发者。

---

## 1. 目标与非目标

### 目标
- 菜单栏常驻，**一眼看到各家最紧张窗口的占用状态**（颜色），点开看完整的 5 小时窗 / 周窗占用百分比与重置倒计时。
- v1 覆盖 **Codex（ChatGPT 套餐）** 与 **Claude（Max/Pro 订阅）**。
- 原生、轻量、可审计、值得信任（要让用户放心把它指向自己的 AI 凭证）。
- 多供应商架构：新增一家 = 实现一个 `QuotaProvider`，不动 UI。

### 非目标（v1 不做，留给 v2+）
- 更多供应商（Gemini/Copilot/…）。
- burn-rate 预测、用量趋势图、多账号池化。
- 跨平台（仅 macOS 14+）。
- 上架 Mac App Store（沙盒会挡住读取本地凭证，技术上不可行）。
- **任何形式的推理代理 / 账号池化 / 负载均衡**（这是各家封号的根源，本项目坚决只读）。

---

## 2. 数据源（均已在本机实测，HTTP 200 ✅）

### 2.1 Codex
两条路，按可用性回退：

**A. 实时端点（主）**
```
GET https://chatgpt.com/backend-api/wham/usage
Headers:
  Authorization: Bearer <access_token>     # 取自 ~/.codex/auth.json tokens.access_token
  chatgpt-account-id: <account_id>         # 取自 tokens.account_id
  Accept: application/json
```
实测返回（节选）：
```jsonc
{
  "plan_type": "prolite",
  "rate_limit": {
    "primary_window":   { "used_percent": 77, "limit_window_seconds": 18000,  "reset_after_seconds": 2478,   "reset_at": 1782107036 },  // 5h
    "secondary_window": { "used_percent": 12, "limit_window_seconds": 604800, "reset_after_seconds": 589278,  "reset_at": 1782693836 }   // 7d
  },
  "additional_rate_limits": [ { "limit_name": "GPT-5.3-Codex-Spark", "rate_limit": { /* primary/secondary */ } } ],
  "credits": { "has_credits": false, "unlimited": false, "balance": "0" }
}
```
优点：`reset_after_seconds` 直接给倒计时，无需算时钟；含每模型子限额、credits、套餐类型。

**B. 本地文件（兜底，零网络）**
解析最新 `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`，向后回溯到最近的 `payload.type == "token_count"` 事件，读 `rate_limits.primary`(5h)/`secondary`(7d)：`used_percent` / `window_minutes` / `resets_at`。无网络可用时使用，UI 标注「数据截至上次使用 CLI」。

### 2.2 Claude
```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <access_token>     # 取自 keychain item "Claude Code-credentials" → claudeAiOauth.accessToken
  anthropic-beta: oauth-2025-04-20
  anthropic-version: 2023-06-01
  User-Agent: claude-code/<version>
```
实测返回（节选）：
```jsonc
{
  "five_hour":         { "utilization": 23.0, "resets_at": "2026-06-22T07:19:59Z" },
  "seven_day":         { "utilization": 11.0, "resets_at": "2026-06-28T10:59:59Z" },
  "seven_day_sonnet":  { "utilization": 3.0,  "resets_at": "2026-06-28T10:59:59Z" },
  "seven_day_opus":    null,
  "extra_usage":       { "is_enabled": true, "used_credits": 3930, "monthly_limit": 10000, "utilization": 39.3, "currency": "USD" },
  "limits": [ { "kind": "session", "group": "session", "percent": 23, "severity": "normal", "resets_at": "...", "is_active": true }, ... ]
}
```
> ⚠️ **合规**：用订阅 OAuth token 从第三方 App 调此端点是 Anthropic 明确禁止的（见 §4）。因此此路径**默认关闭**，仅在用户显式开启高级开关后启用。
> Claude 的本地日志（`~/.claude/projects/**/*.jsonl`、`stats-cache.json`）**不含**限额/重置，只能估算历史 token/成本。

---

## 3. 架构

```
┌─────────────────────────────────────────────┐
│  菜单栏 (单图标 或 多图标，可设置切换)            │
│  颜色 = 所有窗口里最紧张那个的阈值色             │
└───────────────┬─────────────────────────────┘
                │ 点击
        ┌───────▼────────┐
        │  PopoverView    │  左导航(OVERVIEW/CODEX/CLAUDE/SETTINGS) + 右卡片网格
        └───────┬────────┘
                │ 读
        ┌───────▼────────┐
        │   UsageStore    │  轮询调度 · 聚合 · 阈值通知判定 · 缓存
        └───────┬────────┘
                │
     ┌──────────▼───────────┐
     │  QuotaProvider 协议    │ → UsageSnapshot { provider, planType, windows:[Window], extras }
     ├──────────────────────┤   Window { kind:.fiveHour/.weekly/.model, percent, resetsAt, label }
     │  CodexProvider        │
     │  ClaudeProvider       │
     └──────────────────────┘
                │
     ┌──────────▼───────────┐
     │  CredentialStore      │  按供应商的「凭证模式」取 token（见 §5），全部只读
     └──────────────────────┘
```

- **归一化模型** `UsageSnapshot`：两家响应字段不同，统一成同一结构，UI 只认归一化结果。
- 纯 **Swift 6 + SwiftUI `MenuBarExtra`**；`LSUIElement=true`（无 Dock 图标）；**不沙盒**（必须，才能读 `~/.codex` 与 keychain）。
- 每个 provider **feature-flag 化**，可即时禁用（应对接口变动或合规变化）。
- 容错优先：任何字段解析失败 → 显示「未知」而非崩溃（两家端点都是未公开内部接口，会随版本变动）。

---

## 4. 合规（关键，决定 v1 形态）

研究（含对抗验证 + 可核实实锤）结论，两家**完全不对称**：

| | Codex（OpenAI） | Claude（Anthropic） |
|---|---|---|
| 第三方用订阅 OAuth | **灰色但被容忍** | **明确禁止，且服务端封号执行** |
| 依据 | CLI 是 Apache-2.0、官方说可 fork；OpenCode/codex-lb 等在用；2026 年还扩大了对 OSS 的 Codex-plan 支持 | Consumer ToS（2026-01-09 起执行、2-19/20 成文）：在 Claude Code/官方 App 之外用 Free/Pro/Max 的 OAuth token = 违规 |
| 执行力度 | 未封号；主要风险是**接口变动失效** | 自动封号（有的 ~20 分钟内）、服务端指纹、给 OSS 发法务函（OpenCode 因此删掉了 Anthropic OAuth 插件） |
| 风险落点 | 功能失效 | **用户的 $200/月 Max 账号被封** |

**因此采用「混合方案」（用户拍板）：**
- **Codex**：完整 OAuth 登录可做、可作为默认之一（只读、单账号、本地）。
- **Claude**：**默认走合规模式**（本地日志 / Console API key），把「订阅 OAuth 实时配额」做成**默认关闭的高级开关**，开启前弹明确风险提示。开发者自己可开；其他用户默认受保护。

**全局合规红线（两家都遵守）：**
1. **只读**——只读用量/配额，绝不跑推理、不代理、不池化、不负载均衡。
2. 仅用户本人单账号、纯本地、on-device；token 只存 App 自己的 keychain，除官方端点外零外联。
3. 礼貌轮询（分钟级、429 退避、缓存、优先读已有限额头）。
4. **绝不伪造官方客户端的 beta 头**去绕过指纹（这正是 OpenCode 吃法务函的原因）。
5. README/App 内明确定位为「个人、只读、on-device、用自己账号」的看板；收到 takedown 即下架对应 provider。

---

## 5. 账号关联 / 凭证模式（设置里的「账号关联」页）

每家一行，显示关联状态 + 账号邮箱 + 套餐 + 来源；可切换凭证模式：

### Codex
- **复用本机 Codex CLI 登录**（默认，零摩擦）：只读 `~/.codex/auth.json`。
- **用 ChatGPT 登录**（独立 OAuth，支持无 CLI / 多账号）：完整 PKCE 浏览器登录，常量见附录 A（已从 CLI 二进制验证，HIGH 置信）。token 存 **App 自己的 keychain**，不写 `~/.codex/auth.json`。
- **API key**（`sk-…`）：兜底，billed to 用户 API 账户（与 ChatGPT 套餐不同）。

### Claude
- **本地日志**（合规默认）：解析 `~/.claude` 日志，显示历史 token/成本估算（无实时剩余配额与重置）。
- **Console API key**（`sk-ant-api…`，合规）：显示按量付费 API 用量（注意：≠ Max 订阅配额）。
- ⚠️ **高级：复用本机 Claude Code 登录拿实时 Max 配额**（**默认关闭**）：只读 keychain `Claude Code-credentials` 的 token 调 `/api/oauth/usage`，显示真实 5h/周配额 + 重置。**开启前弹风险提示**：「此模式以 Anthropic 条款所禁止的方式使用你的订阅凭证，可能导致账号被封。仅在你自担风险时开启。」
  - 由于 Claude OAuth `client_id` 未知，**不做**独立「用 Claude 登录」；仅复用 CLI 已有 token。token 过期则重读 keychain（CLI 会自行刷新），App 不自己刷新、不改写。

---

## 6. UI / 交互

参考「电池监测 App」风格：深色圆角面板 + 左导航 + 右卡片网格；卡片 = 灰色小标题 + 居中彩色图标/仪表 + 底部粗体值。图标取自 [Iconify](https://icon-sets.iconify.design/)（如 `simple-icons:openai`、`simple-icons:anthropic`、`mdi:gauge`、`mdi:cog`）。

### 菜单栏（收起）—— 设置可切换
- **单图标模式**（默认）：一个图标，按**所有窗口最紧张那个**变色 🟢 `<70%` / 🟠 `≥70%` / 🔴 `≥90%`。不显示数字。
- **多图标模式**（iStat 风格）：每家一个独立菜单栏项（灰标题 + 数值 + 阈值色），技术上每家一个 `MenuBarExtra` scene 用 `isInserted` 开关。

### 弹出面板（约 560×380，深色圆角）
- **左导航**：`OVERVIEW`（各家最紧张窗口一览）/ `CODEX` / `CLAUDE` / …，底部钉 `SETTINGS`。选中项浅色圆角高亮。
- **右卡片网格（2 列）**——选中某家时显示该家卡片：
  - **5-HOUR**：渐变圆环仪表（按 % 着色）+ 粗体 `77%` + 小字 `resets in 41m`。
  - **WEEKLY**：圆环 + `12%` + `6d 20h`。
  - **PLAN**：图标 + `Pro Lite` / `Max`。
  - **CREDITS / EXTRA**：Claude 显示 `$39 / $100`（extra_usage）；Codex 显示 credits 余额。
  - Claude 额外两张：**SONNET**、**OPUS** 周窗（为 null 时隐藏）。
  - `OVERVIEW` 页：每家一张卡（最紧张窗口的圆环 + %）。
- **圆环仪表用 SwiftUI 原生绘制**（`Circle().trim` + 阈值渐变），实时反映 %，非静态图。
- 配色：深灰面板 + 更深卡片、灰标题、白粗值，阈值绿/橙/红点缀，品牌色做导航强调。适配浅/深色与 macOS 26 tinted 菜单栏（图标用 template/SF Symbol）。

### 设置页
① 账号关联（§5）② 显示（单/多图标切换）③ 轮询间隔 ④ 开机自启 ⑤ 通知开关。

---

## 7. 轮询 · 通知 · 安全

- **轮询**：默认每 5 分钟（可调）；**打开面板立即刷新**；出错指数退避；电池/面板隐藏时降频（`NSBackgroundActivityScheduler` 合并唤醒）；不阻塞主线程。
- **通知**：某窗口**上升穿越** 70% / 90% 时发一条 macOS 通知（记录已通知状态去重）。
- **安全**：token 只读、绝不打印/外传；除官方 OpenAI/Anthropic 端点外零外联；token 只存 App 自己的 keychain（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`）；首次读 CLI 的 keychain item 可能弹「允许」框，UI 内说明。401 → 重读凭证源而非缓存。

---

## 8. 打包 · 分发 · CI

- **栈**：原生 Swift 6 + SwiftUI `MenuBarExtra`（必要时降级 `NSStatusItem`+`NSPopover`）；**不沙盒**；Hardened Runtime（公证必需，但不要求沙盒）。
- **分发**：Developer ID 签名 + 公证的 `.dmg`（GitHub Releases）；自建 Homebrew tap（`brew tap elton/tap`，无 notability 门槛；攒到热度后再投 homebrew-cask）；Sparkle 2 自动更新。
- **开机自启**：`SMAppService.mainApp.register()`，处理 `.requiresApproval`；提示用户拖到 `/Applications`（避免 App Translocation 破坏自启与文件访问）。
- **CI**：GitHub Actions（macOS runner）`xcodebuild archive` → codesign（证书从 base64 secret 导入）→ `notarytool submit --wait` → `stapler staple` → `gh release create`。
- 需要：Apple Developer Program（$99/yr）+ Developer ID Application 证书。

---

## 9. v1 范围

**含**：Codex + Claude 双供应商；5h + 周窗双仪表；重置倒计时；70/90% 颜色阈值；菜单栏单/多图标可切换；左导航+卡片网格面板；账号关联（Codex 完整 OAuth + 复用 CLI + API key；Claude 合规默认 + 高级订阅 OAuth 开关）；阈值通知；明细展开（每模型 + credits）；开机自启；手动刷新 + 设置；签名公证 + Homebrew tap + CI。

**不含**：见 §1 非目标。

---

## 10. 项目结构

```
LLMeter.xcodeproj/                 App target, LSUIElement, Hardened Runtime, 不沙盒
Sources/LLMeter/
  App.swift                        @main，MenuBarExtra scene(s)
  StatusController.swift           菜单栏图标/颜色/单多图标切换
  UsageStore.swift                 轮询 + 聚合 + 通知判定 + 缓存
  Models/
    UsageSnapshot.swift            归一化模型（Window/kind/percent/resetsAt/extras）
  Providers/
    QuotaProvider.swift            协议
    CodexProvider.swift            wham/usage + rollout jsonl 兜底
    ClaudeProvider.swift           oauth/usage（高级）+ 本地日志（默认）
  Auth/
    CredentialStore.swift          按凭证模式取 token（只读）
    CodexOAuth.swift               PKCE 登录 + refresh（附录 A）
    Keychain.swift                 App 自有 keychain item 读写
  Views/
    PopoverView.swift  Sidebar.swift  ProviderCardsView.swift
    GaugeRing.swift    SettingsView.swift  AccountsView.swift  RiskDialog.swift
  Resources/Icons/                 Iconify 导出的 SVG/PDF
Tests/
  CodexProviderTests.swift  ClaudeProviderTests.swift   # 用真实响应样例做解析单测
.github/workflows/release.yml      签名/公证/发布
README.md  LICENSE  docs/
```

---

## 11. 风险与待实现期验证项

- **两端点均为未公开内部接口**，CLI 升级可能变动 → 全部容错软化。
- **Codex OAuth**（附录 A）：`/oauth/authorize` 路径、`/deviceauth/*` host、`expires_in`、refresh 是否轮换、回退端口——首次运行验证。
- **Claude 高级路径**合规风险见 §4；默认关闭 + 风险弹窗 + feature-flag 即时禁用。
- **签名公证**需 Apple Developer 账号（$99/yr）——发布前置条件。

---

## 附录 A — Codex OAuth 常量（已从 CLI 二进制验证，HIGH 置信）

| 字段 | 值 |
|---|---|
| client_id | `app_EMoamEEZ73f0CkXaXp7hrann` |
| authorize | `https://auth.openai.com/oauth/authorize` |
| token | `https://auth.openai.com/oauth/token` |
| revoke | `https://auth.openai.com/oauth/revoke` |
| redirect_uri | `http://localhost:{动态端口}/auth/callback`（回环 127.0.0.1） |
| scopes | `openid profile email offline_access api.connectors.read api.connectors.invoke` |
| PKCE | `S256` |
| 刷新 | `POST .../oauth/token` `grant_type=refresh_token&refresh_token=…&client_id=app_EMoam…`（公有客户端，无 secret） |
| 设备码（无头） | `POST .../deviceauth/usercode` → 轮询 `POST .../deviceauth/token` |

> Claude OAuth 独立登录所需的 `client_id` / authorize URL / token path **至今未知**（LOW 置信），故 v1 不做独立登录，仅复用 CLI 既有 token（且默认关闭）。
