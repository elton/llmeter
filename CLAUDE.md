# CLAUDE.md — LLMeter

A native macOS menu-bar app that shows remaining quota + reset time for AI subscription plans. v1 covers **Codex** (ChatGPT plan) and **Claude**; architecture is multi-provider. Swift 6 + SwiftUI, AGPL-3.0.

## Working mandates (user — apply to every task)

- **Maximize concurrency.** Never default to serial. Drive fan-out work (multi-file implementation, multi-dimension review, audits) through one **Workflow** script with `parallel()`/`pipeline()`, or batch **disjoint-file** tasks together. Read-only review/verification runs in parallel with anything. A task starts the moment its dependency lands — don't batch behind a barrier.
  - Caveat for this repo: a single Swift package cannot be built by multiple agents in one working tree (they race on `.build` and the git index). Parallelize by dependency-ordered batches in one tree, or isolated `git worktree`s.
- **Latest stable tech.** Use the newest stable versions the toolchain supports — currently `// swift-tools-version: 6.3` and the **swift-testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest. Verify the environment supports a version before pinning it.
- **Fix all P2-and-above before committing.** Before any commit lands, fix every review finding at **P2 severity or higher** (i.e. P0/P1/P2 ≈ Critical/Important) and add covering tests. Only P3/Minor may be deferred. **Re-run the review and confirm zero P2+ remain before committing** — do not commit on the assumption it's clean.
- **Git discipline in a shared working tree** (when subagents run concurrently): no agent runs `git checkout` / `git reset` / `git stash`; each commits only its own files via `git add <files> && git commit -- <files>` (pathspec), retrying briefly on `index.lock`. Reviewers are read-only (`git show`/`git diff`); for a full snapshot use a temporary detached `git worktree` and remove it after.

## Architecture

- **`LLMeterCore`** (SPM library) — all logic, headless and unit-tested. `swift test` must stay green.
  - `Models/UsageSnapshot` — normalized model. Codex windows carry `percent`; Claude windows are usage-only (`percent == nil`, `resetsAt == nil`, carry `usedTokens`/`estimatedCostUSD`).
  - `QuotaProvider` protocol → `CodexProvider`, `ClaudeProvider`. New provider = new `QuotaProvider`, no UI change.
  - All I/O is injected (`Clock`, `HTTPClient`) so logic is testable with captured fixtures.
- **`llmeter-probe`** (executable) — CLI that prints both providers; used for end-to-end checks.
- The menu-bar app (M2+) depends on `LLMeterCore`. App is **not sandboxed** (must read `~/.codex` / `~/.claude`); macOS 14+.

## Critical constraints

- **Read-only by construction.** Only read usage/quota. Never run inference, proxy, pool, or load-balance accounts. Never mutate `~/.codex` or `~/.claude`, never refresh/rewrite anyone's tokens.
- **Never print, log, or transmit secret tokens.** Tokens flow only into request headers to the official endpoint. Tests use FAKE tokens only.
- **Zero outbound calls except official provider endpoints.**
- **Codex** data: live `GET https://chatgpt.com/backend-api/wham/usage` (token+account_id from `~/.codex/auth.json`) → falls back to newest `~/.codex/sessions/**/rollout-*.jsonl` `rate_limits`. `primary_window`→5h, `secondary_window`→weekly. A 200 with no usable windows must fail (→ fallback), not show empty.
- **Claude is compliant-only.** Do NOT use subscription OAuth in any form — no `/api/oauth/usage`, no `claude setup-token`, no reuse of the `Claude Code-credentials` keychain token. Anthropic prohibits third-party subscription-token use and enforces it with account bans. Claude shows only: local-log usage/cost estimates from `~/.claude/projects/**/*.jsonl`, and optionally a user's own Console API key usage. Surfaced "used tokens" excludes cache *reads* (they re-read cached context and inflate the count); cost still prices them, discounted.
- **Fail soft.** Any parse/IO/network failure degrades to a fallback or `.failure`/`nil`/empty — never a crash. Both providers' endpoints are undocumented internal APIs that drift between versions; pin nothing.

## Build / test / run

```bash
swift test            # full suite (swift-testing) — keep green
swift build
swift run llmeter-probe   # end-to-end: prints live Codex quota + local Claude usage
```

## Where things live

- **Design + implementation plans live locally under `docs/` (git-ignored, not published).** Read them for full context: `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- Roadmap: **M1** core data layer (done) → **M2** menu-bar app + card UI + polling → **M3** Codex OAuth login + notifications + launch-at-login → **M4** signing/notarization + Homebrew + CI.
