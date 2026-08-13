#!/usr/bin/env bash
# Cloud Agent install: bootstrap the mise-managed toolchain and locked
# dependencies for this TypeScript + Python + Rust monorepo scaffold.
#
# Mirrors the canonical flow from README.md and .github/workflows/lint.yml:
#   mise install  ->  pnpm install --frozen-lockfile  ->  uv sync --locked
#
# Idempotent and non-interactive: safe to run repeatedly and against a cached
# or partially prepared environment.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# mise resolves some tools (e.g. AutoCorrect) from GitHub releases and verifies
# their attestations against the GitHub API. Provide a token when one is
# available so those requests aren't anonymously rate-limited; setup still
# proceeds without one.
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  for candidate in "${GH_TOKEN:-}" "${GITHUB_API_TOKEN:-}" "${MISE_GITHUB_TOKEN:-}"; do
    if [[ -n "$candidate" ]]; then
      export GITHUB_TOKEN="$candidate"
      break
    fi
  done
fi
if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  if gh_token="$(gh auth token 2>/dev/null)" && [[ -n "$gh_token" ]]; then
    export GITHUB_TOKEN="$gh_token"
  fi
fi

# Install mise if it isn't already present.
if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
  echo "Installing mise..."
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# Make the mise-managed toolchain available in future (interactive and login)
# shells. ~/.profile sources ~/.bashrc for bash, so this covers both.
activation_marker="# >>> mise activation (cloud agent) >>>"
if ! grep -qF "$activation_marker" "$HOME/.bashrc" 2>/dev/null; then
  {
    printf '%s\n' "$activation_marker"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"'
    printf '%s\n' 'command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"'
    printf '%s\n' "# <<< mise activation (cloud agent) <<<"
  } >>"$HOME/.bashrc"
fi

echo "Installing the repository toolchain (Node.js, pnpm, uv, AutoCorrect)..."
mise trust "$repo_root/mise.toml"
mise install

echo "Installing locked JavaScript dependencies..."
mise exec -- pnpm install --frozen-lockfile

echo "Installing locked Python dependencies..."
mise exec -- uv sync --locked

echo "Cloud Agent install complete."
