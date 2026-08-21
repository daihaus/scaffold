# AGENTS.md

> [!IMPORTANT]
> **This is the upstream scaffold repository (`krosdai.scaffold`).** It ships shared
> project hygiene — toolchain pinning, linting, formatting, Git hooks, and CI — for
> TypeScript + Python + Rust monorepos. It is _not_ an application.
>
> **If you have just bootstrapped a new project from this scaffold, rewrite this file.**
> Replace everything below with guidance specific to the new repository: what it builds,
> its architecture, the real commands, and the conventions an agent must follow. Until then,
> the sections below describe the scaffold itself.

## What this repository is

A minimal bootstrap for TypeScript + Python + Rust monorepos. It intentionally contains no
application framework — only the configuration most repos need before application code exists.
See `README.md` for the full rationale and feature list.

Layout:

- `apps/*`, `packages/*` — workspace members (none yet; this is a clean scaffold).
- Root config files — the shared toolchain. Prefer **extending** these over replacing them.
- `.github/workflows/` — CI: `lint.yml` (all ecosystems) and `code-review.yml` (AI review).
- `.agents/`, `.cursor/` — bootstrap scripts for hosted agent environments (Amp orb lifecycle,
  Cursor Cloud Agent). They mirror `mise run setup`; local development does not run them.

## Toolchain

Tools are pinned and managed by [mise](https://mise.jdx.dev) (`mise.toml`): Node.js, pnpm,
uv, AutoCorrect. Rust is **opt-in** — uncomment the `rust` line in `mise.toml` and run
`mise install` when adding the first crate. Until a crate exists under `apps/` or `packages/`,
the Rust lint/format steps are no-ops (the root `Cargo.toml` is only the workspace manifest).

Setup:

```sh
mise run setup    # mise install + pnpm install + uv sync --locked
```

## Commands

Run these from the repository root.

| Task                   | Command                                                    |
| ---------------------- | ---------------------------------------------------------- |
| Format everything      | `pnpm run format`                                          |
| Lint everything        | `pnpm run lint`                                            |
| Lint one ecosystem     | `pnpm run lint:js` · `lint:py` · `lint:rust` · `lint:text` |
| Auto-fix lint + format | `pnpm run lint:fix`                                        |

- **JS/TS**: Oxlint (type-aware) + Oxfmt. One root `.oxlintrc.json` lints the whole monorepo.
- **Python**: Ruff lint + format, configured in the root `pyproject.toml`; one shared lockfile.
- **Rust**: rustfmt + Clippy (`-D warnings`). No-ops until a crate `Cargo.toml` exists under
  `apps/` or `packages/`.
- **Text/CJK**: AutoCorrect, run through mise.

## Conventions for agents

- **Keep the base small.** Add project-specific tooling deliberately; don't pull in an app
  framework or heavy dependencies into the scaffold itself.
- **Don't modify linter/formatter configs** without explicit human approval. On a lint
  failure, report the rule and location and propose a fix rather than loosening the config.
- **Run `pnpm run lint` before declaring work done.** A fresh checkout is green, including
  the Rust steps (they short-circuit until a crate exists).
- **Adding workspace members**: use the ecosystem's own tooling (`pnpm init`,
  `uv init --package …`, `cargo new …`) so the member lists stay correct.
  See `README.md` → _Adding Workspace Members_.
- **Git hooks** (Husky + lint-staged) run Oxlint/Oxfmt, Ruff, rustfmt, Prettier, and
  AutoCorrect on staged files at commit time; `pre-push` runs Git LFS.

## Commit conventions

Gitmoji + Conventional Commits:

```
<gitmoji> <type>(<scope>): <subject>
```

Common types: ✨ `feat`, 🐛 `fix`, 📝 `docs`, ♻️ `refactor`, ✅ `test`, 🔧 `chore`.
Subject ≤50 chars, lowercase imperative, no trailing period. Keep commits logically split.
