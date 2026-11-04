#!/usr/bin/env bash
# Swap a staged T3 Lab build into /Applications once T3 Lab is not running.
# Run by the io.selfactor.t3lab.updater launchd agent when a build is staged.
set -euo pipefail

state_dir="$HOME/.t3lab"
pending_dir="$state_dir/pending"
target="/Applications/T3 Lab.app"
lock="$state_dir/apply.lock"

[[ -f "$pending_dir/ready" && -d "$pending_dir/T3 Lab.app" ]] || exit 0

# One waiter at a time; a later staging just replaces what it will install.
# A lock whose owner died (reboot, kill) is taken over.
if ! mkdir "$lock" 2>/dev/null; then
  owner="$(cat "$lock/pid" 2>/dev/null || true)"
  # No pid yet means the owner is between mkdir and writing it.
  if [[ -z "$owner" ]] || kill -0 "$owner" 2>/dev/null; then
    exit 0
  fi
  rm -rf "$lock"
  mkdir "$lock"
fi
echo $$ >"$lock/pid"
trap 'rm -rf "$lock"' EXIT

while pgrep -f "/T3 Lab.app/Contents/MacOS/" >/dev/null; do
  sleep 15
done

sha="$(cat "$pending_dir/sha" 2>/dev/null || echo unknown)"
rm -rf "$target.new"
ditto "$pending_dir/T3 Lab.app" "$target.new"
rm -rf "$target"
mv "$target.new" "$target"
# Local builds are ad-hoc signed; clear quarantine so Gatekeeper opens it.
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

printf '%s\n' "$sha" >"$state_dir/deployed-sha"
rm -rf "$pending_dir/T3 Lab.app" "$pending_dir/ready" "$pending_dir/sha"
echo "$(date -u +%FT%TZ) installed T3 Lab $sha"
