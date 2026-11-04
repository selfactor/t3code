#!/usr/bin/env bash
# One-time setup for the daily T3 Lab build on this Mac. Idempotent.
#
# Installs the io.selfactor.t3lab.build launchd agent, which runs build.sh at
# 04:00 each day (it skips when selfactor/t3code main has not moved). Build now:
#   ~/.t3lab/bin/build.sh --force
# or through launchd (logs to ~/.t3lab/build.log):
#   launchctl kickstart gui/$(id -u)/io.selfactor.t3lab.build
#
# Not a GitHub Actions job: selfactor/t3code is a public fork, and Selfactor
# refuses self-hosted runners on public repositories.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
state_dir="$HOME/.t3lab"
bin_dir="$state_dir/bin"
label="io.selfactor.t3lab.build"
plist="$HOME/Library/LaunchAgents/$label.plist"

mkdir -p "$bin_dir" "$HOME/Library/LaunchAgents"
install -m 0755 "$here/build.sh" "$bin_dir/build.sh"

# launchd starts with a bare PATH; give it the tools this shell resolves.
tool_path=""
for tool in git node corepack rustup cargo; do
  dir="$(dirname "$(command -v "$tool")")" || { echo "missing $tool on PATH"; exit 1; }
  case ":$tool_path:" in *":$dir:"*) ;; *) tool_path="${tool_path:+$tool_path:}$dir" ;; esac
done
tool_path="$tool_path:/usr/bin:/bin:/usr/sbin:/sbin"

cat >"$plist.tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>$bin_dir/build.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>4</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$tool_path</string></dict>
  <key>StandardOutPath</key><string>$state_dir/build.log</string>
  <key>StandardErrorPath</key><string>$state_dir/build.log</string>
</dict>
</plist>
PLIST
if ! cmp -s "$plist.tmp" "$plist" 2>/dev/null; then
  mv "$plist.tmp" "$plist"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
else
  rm -f "$plist.tmp"
fi
echo "installed $label (daily 04:00). Build now: launchctl kickstart gui/$(id -u)/$label"
