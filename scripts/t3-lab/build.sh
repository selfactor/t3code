#!/usr/bin/env bash
# Build "T3 Lab.app" from selfactor/t3code main and install it (deploy.sh).
#
#   build.sh          build only if main moved since the last install/staging
#   build.sh --force  build regardless
#
# Run daily by the io.selfactor.t3lab.build launchd agent (see setup.sh), or by
# hand. Builds in its own checkout (~/.t3lab/src) so working worktrees are
# never touched. Output goes to ~/.t3lab/build.log when run by launchd.
set -euo pipefail

force=false
[[ "${1:-}" == "--force" ]] && force=true

repo_url="git@github.com:selfactor/t3code.git"
state_dir="$HOME/.t3lab"
src="$state_dir/src"
out="$state_dir/release"
lock="$state_dir/build.lock"

mkdir -p "$state_dir"
if ! mkdir "$lock" 2>/dev/null; then
  owner="$(cat "$lock/pid" 2>/dev/null || true)"
  if [[ -z "$owner" ]] || kill -0 "$owner" 2>/dev/null; then
    echo "$(date -u +%FT%TZ) a T3 Lab build is already running"
    exit 0
  fi
  rm -rf "$lock"
  mkdir "$lock"
fi
echo $$ >"$lock/pid"
trap 'rm -rf "$lock"' EXIT

echo "$(date -u +%FT%TZ) T3 Lab build check"
if [[ ! -d "$src/.git" ]]; then
  git clone --quiet "$repo_url" "$src"
fi
git -C "$src" fetch --quiet --prune origin
sha="$(git -C "$src" rev-parse origin/main)"
installed="$(cat "$state_dir/deployed-sha" 2>/dev/null || true)"
staged="$(cat "$state_dir/pending/sha" 2>/dev/null || true)"
if [[ "$force" != true && ( "$sha" == "$installed" || "$sha" == "$staged" ) ]]; then
  echo "main is at $sha, already installed or staged; nothing to do."
  exit 0
fi

git -C "$src" checkout --quiet --force --detach "$sha"
git -C "$src" clean -fdxq -e node_modules

# pnpm's self-switch to packageManager breaks outside a login shell; resolve
# pnpm (here and inside the packager) through a corepack shim instead.
mkdir -p "$state_dir/shims"
corepack enable --install-directory "$state_dir/shims" pnpm
export PATH="$state_dir/shims:$PATH"

cd "$src"
pnpm install --frozen-lockfile
rm -rf "$out"
# The resource monitor needs rustc 1.95+; pin it so the default stable is left
# alone. The packager reads it from the crate's own target dir.
rustup toolchain install 1.95.0 --profile minimal --target aarch64-apple-darwin >/dev/null
env -u CARGO_TARGET_DIR RUSTUP_TOOLCHAIN=1.95.0 T3CODE_DESKTOP_VARIANT=lab \
  npx vp run dist:desktop:artifact --platform mac --target dir --arch arm64 --output-dir "$out"

app="$(find "$out" -maxdepth 3 -name 'T3 Lab.app' -type d | head -1)"
[[ -n "$app" ]] || { echo "no T3 Lab.app in $out"; exit 1; }
"$src/scripts/t3-lab/deploy.sh" "$app" "$sha"
echo "$(date -u +%FT%TZ) T3 Lab build $sha done"
