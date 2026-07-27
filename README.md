# Monorepo Scaffold

A minimal bootstrap scaffold for TypeScript + Python + Rust monorepos.

This repository is intentionally small. It provides the shared project hygiene that most
repositories need before application code exists: tool and package manager pinning, strict
TypeScript defaults, a modern Python toolchain (uv + Ruff), a Rust toolchain (Cargo +
rustfmt + Clippy), formatting, linting, staged-file checks, and CI.

## What Is Included

Shared:

- mise config for unified tool management (Node.js, pnpm, uv, AutoCorrect; Rust is opt-in)
- Prettier formatting for docs and config file types (Markdown, JSON, YAML, HTML,
  CSS, Vue, GraphQL, and more — see the globs in `package.json`)
- AutoCorrect CJK copywriting cleanup
- Husky pre-commit and pre-push hooks with lint-staged
- GitHub Actions lint and AI code-review workflows
- Basic `.env.example` and `.gitignore` files

TypeScript:

- pnpm workspace over `apps/*` and `packages/*`
- Strict `tsconfig.json` defaults
- [Oxlint](https://oxc.rs/docs/guide/usage/linter) with type-aware rules
  (`oxlint-tsgolint`) — one root `.oxlintrc.json` lints the whole monorepo
- [Oxfmt](https://oxc.rs/docs/guide/usage/formatter) formatting for the JS/TS family
  (Prettier-compatible output, configured in `.oxfmtrc.jsonc`)

Python:

- uv workspace under `apps/` and `packages/` with a single shared lockfile
- Ruff linter + formatter configured in the root `pyproject.toml`
- Python version pinned in `.python-version` (uv installs it automatically)

Rust:

- Cargo workspace under `apps/` and `packages/` with a single shared `Cargo.lock`
- [rustfmt](https://rust-lang.github.io/rustfmt/) formatting (`rustfmt.toml`, edition 2024)
- [Clippy](https://doc.rust-lang.org/clippy/) linting, run with `-D warnings` so any lint
  fails `pnpm run lint`
- Toolchain opt-in via mise: uncomment `rust` in `mise.toml` when you add your first crate
  (it pins `rust = "1.93"` with the rustfmt + clippy components). Until then the Rust
  lint/format steps are no-ops, so repos without Rust don't install the toolchain.

## What Is Not Included

- No app framework
- No build tool
- No test runner
- No runtime entrypoint
- No generated source tree

Add those only when a real project needs them.

## Layout

```
apps/        # deployable applications (TypeScript, Python, or Rust)
packages/    # shared libraries (TypeScript, Python, or Rust)
```

TypeScript, Python, and Rust members share the same two directories, and a member can even
belong to more than one ecosystem. pnpm discovers members through the `apps/*` / `packages/*`
globs in `pnpm-workspace.yaml`: a directory joins by having a `package.json`. Python and Rust
members are instead listed explicitly — Python in `[tool.uv.workspace]` in the root
`pyproject.toml`, Rust in `[workspace] members` in the root `Cargo.toml`. Both uv and Cargo
require every member-glob match to be a project of their own kind, so a glob like `apps/*`
would break the moment a member of another ecosystem appears; explicit lists avoid that.
`uv init` and `cargo new` maintain their respective member lists for you.

## Quick Start

With [mise](https://mise.jdx.dev) (recommended — installs Node.js, pnpm, uv, and AutoCorrect):

```sh
mise run setup
```

[Activate mise](https://mise.jdx.dev/getting-started.html) in your shell so the managed
tools are on PATH. AutoCorrect is managed through mise, and package scripts call
`mise run` / `mise x` for those checks.

Package scripts require `mise` because AutoCorrect runs through the repo-managed
toolchain. If you manage Node.js, pnpm, or uv yourself, still run `mise install`
so the configured tools are available before running package scripts:

```sh
mise install
pnpm install
uv sync --locked
```

Rust is opt-in (see [Adding Workspace Members](#adding-workspace-members)). Once a toolchain
is available, Cargo resolves Rust dependencies on the first build — there is no separate
install step.

## Commands

Format files (Oxfmt + Prettier + Ruff + rustfmt + AutoCorrect):

```sh
pnpm run format
```

Run all lint checks (Oxlint + Oxfmt + Prettier, Ruff, rustfmt + Clippy, AutoCorrect):

```sh
pnpm run lint
```

Run lint checks for one ecosystem:

```sh
pnpm run lint:js
pnpm run lint:py
pnpm run lint:rust
pnpm run lint:text
```

The Rust steps are no-ops until the first crate exists, so `pnpm run lint` stays green on a
fresh checkout before any Rust code is added.

Run lint fixes and formatting:

```sh
pnpm run lint:fix
```

## Adding Workspace Members

A TypeScript package:

```sh
mkdir -p packages/my-lib && cd packages/my-lib && pnpm init
```

Give it a `tsconfig.json` extending the root one. The root `pnpm run lint` already lints
every workspace file with Oxlint (one root `.oxlintrc.json`, run once for the whole repo);
add a nested `.oxlintrc.json` with `"extends": ["../../.oxlintrc.json"]` only when the
member needs different rules, and `lint` / `lint:fix` scripts only for extra member-specific
checks — `pnpm -r run --if-present lint` picks them up.

A Python package:

```sh
uv init --package packages/my-tool && uv sync
```

`uv init` appends the member to `[tool.uv.workspace]` in the root `pyproject.toml`
automatically; Ruff settings are inherited from the root, and all members share one
lockfile and virtual environment.

A Rust crate (first enable the opt-in toolchain by uncommenting the `rust` line in
`mise.toml`, then `mise install`):

```sh
cargo new packages/my-crate        # use --lib for a library, default is a binary
cargo generate-lockfile            # create Cargo.lock so the locked lint passes; commit it
```

`cargo new` appends the crate to `[workspace] members` in the root `Cargo.toml`
automatically, and — because the root declares `[workspace.package]` — the generated
`Cargo.toml` already inherits shared metadata via `edition.workspace = true` and
`rust-version.workspace = true`. rustfmt and Clippy settings are inherited from the root too,
and all members share one `Cargo.lock` and `target/` directory. `lint:rust` runs Clippy with
`--locked`, so commit `Cargo.lock` (CI fails if it is missing or stale). Until the toolchain
is enabled, the Rust lint/format steps stay no-ops and CI never installs Rust.

## Git Hooks

- `pre-commit` runs lint-staged: Oxlint + Oxfmt on staged JS/TS, Ruff on staged Python,
  rustfmt on staged Rust, Prettier on staged docs/config files, plus AutoCorrect on all
  staged files.
- `pre-push` runs Git LFS, so `git-lfs` must be installed.

The hooks need pnpm, uv, and AutoCorrect on PATH (plus rustfmt only when committing Rust).
If a GUI Git client doesn't load your shell profile, provide them via husky's
`~/.config/husky/init.sh`, e.g. `eval "$(mise activate bash --shims)"`.

## Usage

Start from this scaffold when you want a clean TypeScript + Python + Rust repository
foundation without choosing an application framework up front. Keep the base small, add
project-specific tools deliberately, and prefer extending the existing config over
replacing it.
