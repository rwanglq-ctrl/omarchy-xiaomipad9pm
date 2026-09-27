#!/usr/bin/env bash
# privacy-scan.sh — scan repo files for leaked personal data
# Usage: tools/privacy-scan.sh [DIR]   (default: repo root)
# Exit 0 = clean, exit 1 = findings reported
# Requirements: bash ≥4, grep, find. Uses rg (ripgrep) if available for speed.
#
# Owner-specific patterns are loaded from an optional local file:
#   ${OMARCHY_ALARM_PRIVATE_PATTERNS:-$HOME/.config/omarchy-alarm/private-patterns.txt}
# One PCRE per line, '#' comments. The current $USER (≥3 chars) is also
# checked automatically with word boundaries.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAN_DIR="${1:-$REPO_ROOT}"
ALLOWLIST="$REPO_ROOT/tools/privacy-allowlist.txt"

findings=0

# Run one search. Exit status 1 only means "no match"; anything higher is a scanner
# error (bad regex, unreadable file) and must fail the scan, never read as "clean".
search() {
  local out rc=0
  out=$("$@") || rc=$?
  if (( rc > 1 )); then
    echo "privacy-scan: search failed (exit $rc): $*" >&2
    return 2
  fi
  printf '%s' "$out" | { grep -v '/\.git/' || true; }
}

report() {
  echo "$1:$2:$3"
  findings=$((findings + 1))
}

# Load allowlist patterns (for filtering findings, not scan input)
allowlist_patterns=()
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r pat; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    allowlist_patterns+=("$pat")
  done < "$ALLOWLIST"
fi

is_allowed() {
  local file="$1" line="$2" rule="$3"
  local loc="${file}:${line}:${rule}"
  for pat in "${allowlist_patterns[@]}"; do
    if printf '%s' "$loc" | grep -qP "$pat" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# Load owner-specific patterns from local file (optional)
PRIVATE_PATTERNS_FILE="${OMARCHY_ALARM_PRIVATE_PATTERNS:-$HOME/.config/omarchy-alarm/private-patterns.txt}"
private_patterns=()
if [[ -f "$PRIVATE_PATTERNS_FILE" ]]; then
  while IFS= read -r pat; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    private_patterns+=("$pat")
  done < "$PRIVATE_PATTERNS_FILE"
fi

# Auto-add current $USER if ≥3 chars (word-boundary match). Generic build/CI
# account names are not personal and appear legitimately in the test harness.
CURRENT_USER="${USER:-}"
GENERIC_USERS='^(root|tester|testuser|runner|ubuntu|builder|build|user|nobody|alpm)$'
if [[ ${#CURRENT_USER} -ge 3 && ! "$CURRENT_USER" =~ $GENERIC_USERS ]]; then
  private_patterns+=("(?<![\\w])${CURRENT_USER}(?![\\w])")
fi

# Run owner-specific patterns as a combined scan
run_private_scan() {
  if [[ ${#private_patterns[@]} -eq 0 ]]; then
    return
  fi
  # Build one combined PCRE pattern (patterns may use lookarounds)
  local combined=""
  for pat in "${private_patterns[@]}"; do
    if [[ -z "$combined" ]]; then
      combined="$pat"
    else
      combined="${combined}|${pat}"
    fi
  done
  local results
  results=$(search grep -rnP "$combined" "$SCAN_DIR") || exit 2
  if [[ -n "$results" ]]; then
    while IFS= read -r match; do
      local file="${match%%:*}"
      local rest="${match#*:}"
      local line="${rest%%:*}"
      case "$file" in
        */privacy-scan.sh|*/privacy-allowlist.txt|*/privacy-selftest.sh) continue ;;
      esac
      is_allowed "$file" "$line" "private-pattern" && continue
      report "$file" "$line" "private-pattern"
    done <<< "$results"
  fi
}

# Determine scanner
if command -v rg >/dev/null 2>&1; then
  SCAN=(rg --no-heading --line-number --color=never --hidden -P -g '!.git')
  SCAN_CASE=(rg --no-heading --line-number --color=never --hidden -Pi -g '!.git')
else
  SCAN=(grep -rnP)
  SCAN_CASE=(grep -rniP)
fi

# Helper: run a scan, filter allowlist, report
run_scan() {
  local rule="$1"
  shift
  local results
  results=$(search "$@" "$SCAN_DIR") || exit 2
  if [[ -n "$results" ]]; then
    while IFS= read -r match; do
      local file="${match%%:*}"
      local rest="${match#*:}"
      local line="${rest%%:*}"
      # Skip the scanner itself and the allowlist
      case "$file" in
        */privacy-scan.sh|*/privacy-allowlist.txt|*/privacy-selftest.sh) continue ;;
      esac
      is_allowed "$file" "$line" "$rule" && continue
      report "$file" "$line" "$rule"
    done <<< "$results"
  fi
}

echo "=== Privacy Scan ===" >&2
echo "Scanning: $SCAN_DIR" >&2

# --- Generic absolute-home rule (/home/<name>/, /Users/<name>/) ---
# Every literal home directory in a line must use a neutral placeholder name;
# $HOME, ~, ${HOME}, /home/$USER style references never match the pattern at all.
PLACEHOLDER_NAMES='^(testuser|user|username|yourname|you|example|USER|NAME)$'
home_results=$(search grep -rnP '(?<![$~{])/(home|Users)/[a-zA-Z][a-zA-Z0-9_-]*/' "$SCAN_DIR") || exit 2
if [[ -n "$home_results" ]]; then
  while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    content="${rest#*:}"
    case "$file" in
      */privacy-scan.sh|*/privacy-allowlist.txt|*/privacy-selftest.sh) continue ;;
    esac
    real_name=0
    while IFS= read -r name; do
      [[ -z "$name" || "$name" =~ $PLACEHOLDER_NAMES ]] || real_name=1
    done < <(printf '%s\n' "$content" | grep -oP '(?<![$~{])/(home|Users)/\K[a-zA-Z][a-zA-Z0-9_-]*(?=/)' || true)
    (( real_name )) || continue
    is_allowed "$file" "$line" "absolute-home" && continue
    report "$file" "$line" "absolute-home"
  done <<< "$home_results"
fi

# --- Email addresses (allow noreply@, example.com, example.org) ---
email_results=$(search "${SCAN[@]}" '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$SCAN_DIR") || exit 2
if [[ -n "$email_results" ]]; then
  while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    content="${match#*:}"
    content="${content#*:}"
    case "$file" in
      */privacy-scan.sh|*/privacy-allowlist.txt|*/privacy-selftest.sh) continue ;;
    esac
    # Skip noreply@, example.com, example.org
    if printf '%s' "$content" | grep -qP '(noreply@|@example\.com|@example\.org)' 2>/dev/null; then
      continue
    fi
    is_allowed "$file" "$line" "email-address" && continue
    report "$file" "$line" "email-address"
  done <<< "$email_results"
fi

# --- @localhost authors ---
run_scan "localhost-author" "${SCAN[@]}" '^\s*(From|Author|Signed-off-by).*@localhost'

# --- Private keys ---
run_scan "private-key" "${SCAN[@]}" 'BEGIN .* PRIVATE KEY'

# --- Token patterns ---
run_scan "github-token" "${SCAN[@]}" 'ghp_[A-Za-z0-9]{36,}'
run_scan "github-pat" "${SCAN[@]}" 'github_pat_[A-Za-z0-9_-]{20,}'
run_scan "anthropic-key" "${SCAN[@]}" 'sk-ant-[A-Za-z0-9_-]{20,}'
run_scan "openai-key" "${SCAN[@]}" '\bsk-[A-Za-z0-9_-]{20,}'
run_scan "slack-token" "${SCAN[@]}" 'xox[baprs]-[A-Za-z0-9-]{20,}'
run_scan "aws-key" "${SCAN[@]}" 'AKIA[0-9A-Z]{16}'
run_scan "google-api-key" "${SCAN[@]}" 'AIza[0-9A-Za-z_-]{35}'
run_scan "gitlab-token" "${SCAN[@]}" 'glpat-[A-Za-z0-9_-]{20,}'
run_scan "bearer-token" "${SCAN_CASE[@]}" 'bearer\s+[A-Za-z0-9._-]{20,}'
run_scan "password-value" "${SCAN_CASE[@]}" 'password\s*=\s*\S+'

# --- Hex/base64 blobs > 32 chars (require real high entropy) ---
# Hex blob: ≥32 hex chars with at least one uppercase AND one digit.
# This rejects all-lowercase paths (e.g. omarchy/current/theme/foot)
# and git SHAs (all lowercase), while catching real secret tokens.
run_scan "hex-blob" "${SCAN[@]}" '(?<![A-Fa-f0-9_./-])(?=[A-Fa-f0-9]{32,}(?:[^A-Fa-f0-9]|$))(?=.*[A-F])(?=.*[0-9])[A-Fa-f0-9]{32,}'
# Base64 blob: ≥32 base64 chars with at least one digit.
# Real base64 secrets contain digits; pure-lowercase paths do not.
run_scan "base64-blob" "${SCAN[@]}" '(?<![A-Za-z0-9/+=_./-])(?=[A-Za-z0-9+/]{32,}(?:[^A-Za-z0-9/+=]|$))(?=.*[0-9])[A-Za-z0-9+/]{32,}={0,2}'

# --- UUIDs ---
run_scan "uuid" "${SCAN[@]}" '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# --- IPv4 addresses outside documentation ranges ---
ipv4_results=$(search "${SCAN[@]}" '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' "$SCAN_DIR") || exit 2
if [[ -n "$ipv4_results" ]]; then
  while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    content="${match#*:}"
    content="${content#*:}"
    case "$file" in
      */privacy-scan.sh|*/privacy-allowlist.txt|*/privacy-selftest.sh) continue ;;
    esac
    ip="$(printf '%s' "$content" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' || true)"
    if [[ -n "$ip" ]]; then
      # Skip documentation/example ranges
      if printf '%s' "$ip" | grep -qP '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|0\.0\.0\.0|255\.255\.255\.255|198\.51\.100\.|203\.0\.113\.|169\.254\.)' 2>/dev/null; then
        continue
      fi
      is_allowed "$file" "$line" "ipv4-address" && continue
      report "$file" "$line" "ipv4-address"
    fi
  done <<< "$ipv4_results"
fi

# --- Rime user data references ---
run_scan "rime-user-data" "${SCAN[@]}" '\.(userdb|custom_phrase\.txt|user\.yaml|installation\.yaml)'
# Also scan for sync/ directory references in Rime context
run_scan "rime-sync-dir" "${SCAN[@]}" '(?:^|/)(?:rime|sync)/.*(?:userdb|custom_phrase|user\.yaml|installation\.yaml)'

# --- Browser profile filenames ---
run_scan "browser-profile-file" "${SCAN[@]}" '\b(Cookies|Login Data|History|Local State)\b'

# --- Owner-specific patterns from local file ---
run_private_scan

# --- Check for backup files ---
while IFS= read -r -d '' f; do
  echo "${f}:0:backup-file"
  findings=$((findings + 1))
done < <(find "$SCAN_DIR" -path '*/.git' -prune -o \( -name '*.bak' -o -name '*.bak.*' -o -name '*~' \) -print0 2>/dev/null)

# --- Check for Rime userdb/custom_phrase/sync/user.yaml/installation.yaml files ---
while IFS= read -r -d '' f; do
  echo "${f}:0:rime-userdb-file"
  findings=$((findings + 1))
done < <(find "$SCAN_DIR" -path '*/.git' -prune -o \( -name '*.userdb' -o -name '*.userdb.kct' -o -name 'custom_phrase.txt' -o -name 'user.yaml' -o -name 'installation.yaml' \) -print0 2>/dev/null)

# --- Check for browser profile filenames as standalone files ---
for bf in "Cookies" "Login Data" "History" "Local State"; do
  while IFS= read -r -d '' f; do
    echo "${f}:0:browser-profile"
    findings=$((findings + 1))
  done < <(find "$SCAN_DIR" -path '*/.git' -prune -o -name "$bf" -print0 2>/dev/null)
done

echo "" >&2
if (( findings > 0 )); then
  echo "Privacy scan: ${findings} finding(s) detected." >&2
  exit 1
else
  echo "Privacy scan: clean." >&2
  exit 0
fi
