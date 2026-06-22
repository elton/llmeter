# LLMeter

> 菜单栏里的 AI 订阅配额表 — 一眼掌握 Codex、Claude 等大模型订阅套餐的剩余限额与重置时间。
>
> A macOS menu bar gauge for your AI subscription quotas. See your Codex / Claude usage windows and reset times at a glance.

**状态：早期开发中（设计已定稿，见 [`docs/superpowers/specs`](docs/superpowers/specs/)）。**

## 是什么

一个常驻 macOS 菜单栏的原生小工具（Swift + SwiftUI）。收起时只是一个会变色的图标（🟢 充裕 / 🟠 ≥70% / 🔴 ≥90%）；点开看每家的 **5 小时窗 / 周窗**占用百分比、重置倒计时、每模型子限额与额外用量额度。

v1 支持：

- **Codex**（ChatGPT 套餐）— 读 5h/周窗占用、重置、每模型子限额、credits。
- **Claude**（Max/Pro 订阅）— 默认走合规模式；实时订阅配额为默认关闭的高级选项（见下方说明）。

## 设计原则 / 信任

这是一个会接触你 AI 凭证的工具，所以：

- **只读**：只读取用量/配额，**绝不**运行推理、代理请求、池化或负载均衡账号。
- **纯本地、on-device**：凭证只存在你本机的 keychain，除官方 OpenAI / Anthropic 端点外**零外联**，无任何服务器中转。
- **单账号、你自己的账号**：定位为个人只读看板。
- 开源可审计（AGPL-3.0）。

## ⚠️ 关于 Claude 的合规说明（请先读）

Anthropic 的条款**禁止**在 Claude Code / 官方 App 之外的第三方工具中使用 Free/Pro/Max 订阅的 OAuth 凭证，并已在服务端执行（封号）。因此 LLMeter：

- **默认**对 Claude 使用合规方式（本地日志的历史用量 / 可选的 Console API key）。
- 「用订阅凭证拉取实时 Max 配额」是一个**默认关闭的高级开关**，开启前会明确提示封号风险，由你自担风险决定。

Codex 侧：OpenAI 未作等同限制（CLI 为 Apache-2.0、官方表示可 fork），但本工具同样坚持只读、礼貌轮询、忠实于官方请求形态。

> 免责声明：本软件按「现状」提供，不附带任何担保。两家所用接口均为未公开内部接口，可能随时变动或失效。使用风险由你自行承担。

## 安装

> 即将提供：签名公证的 `.dmg`（GitHub Releases）与 Homebrew tap（`brew tap elton/tap`）。

## 开发

需要 macOS 14+ 与 Xcode。详见设计文档。

## 许可证

[AGPL-3.0](LICENSE) © 2026 Elton Zheng
