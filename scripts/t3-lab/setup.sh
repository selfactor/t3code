#!/usr/bin/env bash
# One-time setup for the T3 Lab local build on this Mac. Idempotent.
#  1. Turn on Actions for the fork, keeping only the T3 Lab workflow enabled
#     (upstream's release/CI workflows must not run under selfactor/t3code).
#  2. Register this Mac as a self-hosted runner for selfactor/t3code.
#  3. Create the daily Selfactor machine job that dispatches the build.
set -euo pipefail

repo="selfactor/t3code"
keep="t3-lab-local.yml"
here="$(cd "$(dirname "$0")" && pwd)"

echo "== Actions: enable for $repo"
gh api -X PUT "repos/$repo/actions/permissions" -F enabled=true -f allowed_actions=all >/dev/null

echo "== Actions: disable every workflow except $keep"
gh api "repos/$repo/actions/workflows" --paginate -q '.workflows[] | select(.path | startswith(".github/workflows/")) | "\(.id) \(.path) \(.state)"' |
  while read -r id path state; do
    if [[ "$(basename "$path")" == "$keep" ]]; then
      [[ "$state" == "active" ]] || gh api -X PUT "repos/$repo/actions/workflows/$id/enable" >/dev/null
      echo "   keep    $path"
    elif [[ "$state" == "active" ]]; then
      gh api -X PUT "repos/$repo/actions/workflows/$id/disable" >/dev/null
      echo "   disable $path"
    fi
  done

echo "== Runner: this Mac for $repo"
if self actions runner status 2>/dev/null | grep -q "^$repo registered=true"; then
  echo "   already registered"
else
  self actions runner install --repo "$repo"
fi

echo "== Selfactor job: daily dispatch"
if self jobs list --text 2>/dev/null | grep -q "T3 Lab local build"; then
  echo "   already exists"
else
  machine_id="$(tr -d '[:space:]' <"$HOME/.selfactor/machine-id")"
  job_file="$(mktemp -t t3-lab-job).yaml"
  sed "s/MACHINE_ID/$machine_id/" "$here/job.yaml" >"$job_file"
  self jobs create "$job_file"
  rm -f "$job_file"
fi

cat <<EOF

Done. Build now with either:
  gh workflow run $keep -R $repo -f force=true
  self jobs run-now <job id from: self jobs list>
EOF
