#!/usr/bin/env bash
# Writes a GitHub Actions step summary from efvibe --json scan output.
set -euo pipefail

json_path="${1:?usage: efvibe-job-summary.sh <scan.json> [title]}"
title="${2:-efvibe scan}"

if [[ ! -f "$json_path" ]]; then
  {
    echo "## $title"
    echo ""
    echo "No JSON output file found (\`$json_path\`). The scan step may have failed before writing results."
  } >>"$GITHUB_STEP_SUMMARY"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y -qq jq
fi

{
  echo "## $title"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  jq -r '
    "| Files scanned | \(.filesScanned) |",
    "| Projects scanned | \(.projectsScanned) |",
    "| Total findings | \(.totalFindings) |",
    "| Critical | \(.criticalCount) |",
    "| Error | \(.errorCount) |",
    "| Warning | \(.warningCount) |",
    "| Info | \(.infoCount) |",
    (if .querySitesVisited != null then "| Query sites (deep) | \(.querySitesVisited) |" else empty end),
    (if .sqlTranslatedCount != null then "| SQL translated | \(.sqlTranslatedCount) |" else empty end),
    (if .queryPlanCount != null then "| EXPLAIN plans | \(.queryPlanCount) |" else empty end),
    "| CI gate (\(.failOn // "none")) | \(if .ciFailed then "failed" else "passed" end) |"
  ' "$json_path"
  echo ""
  echo "### Top findings"
  echo ""
  echo "| Severity | Rule | File | Line | Message |"
  echo "|----------|------|------|------|---------|"
  jq -r '
    .findings
    | sort_by(
        if .severity == "critical" then 0
        elif .severity == "error" then 1
        elif .severity == "warning" then 2
        else 3 end)
    | .[0:25][]
    | "| \(.severity) | \(.ruleId) | `\(.file)` | \(.line) | \(.message | gsub("\\|"; "/")) |"
  ' "$json_path"
  echo ""
  echo "Artifact: \`$json_path\` · Full session file path in JSON: \`$(jq -r .savedPath "$json_path")\`"
} >>"$GITHUB_STEP_SUMMARY"
