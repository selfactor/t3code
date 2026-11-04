#!/usr/bin/env bash
# Install a freshly built "T3 Lab.app" into /Applications.
#
#   deploy.sh <path/to/T3 Lab.app> <commit-sha>
#
# If T3 Lab is running, the build is staged under ~/.t3lab/pending and a
# launchd agent swaps it in after the app quits. launchd, not the Actions
# runner, owns that wait, so it survives the job ending.
set -euo pipefail

src_app="${1:?usage: deploy.sh <T3 Lab.app> <sha>}"
sha="${2:?usage: deploy.sh <T3 Lab.app> <sha>}"
script_dir="$(cd "$(dirname "$0")" && pwd)"

state_dir="$HOME/.t3lab"
pending_dir="$state_dir/pending"
bin_dir="$state_dir/bin"
agent_label="io.selfactor.t3lab.updater"
agent_plist="$HOME/Library/LaunchAgents/$agent_label.plist"

mkdir -p "$pending_dir" "$bin_dir" "$HOME/Library/LaunchAgents"

# The updater must outlive the runner's checkout, so it runs from a stable copy.
install -m 0755 "$script_dir/apply-pending.sh" "$bin_dir/apply-pending.sh"

cat >"$agent_plist.tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$agent_label</string>
  <key>ProgramArguments</key>
  <array><string>$bin_dir/apply-pending.sh</string></array>
  <key>WatchPaths</key>
  <array><string>$pending_dir/ready</string></array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$state_dir/updater.log</string>
  <key>StandardErrorPath</key><string>$state_dir/updater.log</string>
</dict>
</plist>
PLIST
if ! cmp -s "$agent_plist.tmp" "$agent_plist" 2>/dev/null; then
  mv "$agent_plist.tmp" "$agent_plist"
  launchctl bootout "gui/$(id -u)/$agent_label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$agent_plist"
else
  rm -f "$agent_plist.tmp"
fi

# Stage, then let the updater apply it (now if T3 Lab is closed, else on quit).
rm -rf "$pending_dir/T3 Lab.app" "$pending_dir/ready"
ditto "$src_app" "$pending_dir/T3 Lab.app"
printf '%s\n' "$sha" >"$pending_dir/sha"
date -u +%FT%TZ >"$pending_dir/ready"

if pgrep -f "/T3 Lab.app/Contents/MacOS/" >/dev/null; then
  echo "T3 Lab is running; $sha is staged and installs when it quits."
else
  "$bin_dir/apply-pending.sh"
fi
