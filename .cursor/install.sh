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

# --- 1. Install mise --------------------------------------------------------
# This runs BEFORE any GitHub credential is placed in the environment, so the
# mise.run bootstrap never has access to a token (defense in depth). mise's own
# installer verifies the signature of the release it downloads. Mirrors the
# repo's .agents/setup.
if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
  echo "Installing mise..."
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# --- 2. Persist mise activation for future shells ---------------------------
# Shims mode is used (matching .agents/setup) so tools resolve reliably in
# non-interactive shells that never run the prompt hook.
activation_start="# >>> mise activation (cloud agent) >>>"
activation_end="# <<< mise activation (cloud agent) <<<"

write_activation_block() {
  # Idempotently (re)write a self-contained, delimited activation block into
  # the given file. Any existing block is removed first — including a partial
  # one left by an interrupted run (opening marker present, closing marker
  # missing) — so reruns always converge on exactly one complete block.
  local file="$1"
  mkdir -p -- "$(dirname -- "$file")"
  [[ -e "$file" ]] || : >"$file"
  if grep -qF "$activation_start" "$file"; then
    awk -v s="$activation_start" -v e="$activation_end" '
      $0 == s { drop = 1; next }
      drop && $0 == e { drop = 0; next }
      !drop { print }
    ' "$file" >"$file.mise.tmp"
    mv -- "$file.mise.tmp" "$file"
  fi
  cat >>"$file" <<EOF
$activation_start
export PATH="\$HOME/.local/bin:\$PATH"
if command -v mise >/dev/null 2>&1; then
  case ":\$PATH:" in
    *":\$HOME/.local/share/mise/shims:"*) ;;
    *) eval "\$(mise activate bash --shims)" ;;
  esac
fi
$activation_end
EOF
}

# Cloud Agents run login shells, which read ~/.bash_profile and fall back to
# ~/.profile only when ~/.bash_profile is absent; a base image's ~/.bashrc may
# also return early for non-interactive shells. Writing the block directly to
# ~/.bash_profile guarantees login shells activate mise regardless, while
# seeding a missing ~/.bash_profile to source ~/.profile preserves the default
# login behavior. ~/.bashrc is also covered for interactive non-login shells.
if [[ ! -e "$HOME/.bash_profile" ]]; then
  printf '%s\n' '[ -f "$HOME/.profile" ] && . "$HOME/.profile"' >"$HOME/.bash_profile"
fi
write_activation_block "$HOME/.bash_profile"
write_activation_block "$HOME/.bashrc"

# --- 3. Resolve a GitHub token (only after the mise bootstrap) --------------
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

# --- 4. Install the toolchain and locked dependencies -----------------------
echo "Installing the repository toolchain (Node.js, pnpm, uv, AutoCorrect)..."
mise trust "$repo_root/mise.toml"
mise install

echo "Installing locked JavaScript dependencies..."
mise exec -- pnpm install --frozen-lockfile

echo "Installing locked Python dependencies..."
mise exec -- uv sync --locked

echo "Cloud Agent install complete."
