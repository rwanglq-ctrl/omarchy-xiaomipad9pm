#!/usr/bin/env bash
# privacy-selftest.sh — validate that privacy-scan.sh detects all planted cases
# Uses NEUTRAL placeholder values (user 'alice', app 'ExampleChat').
# Generates test files in a temp dir, runs the scanner, asserts each rule fires,
# then verifies a clean dir passes. Exits 0 on success, 1 on failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCANNER="$SCRIPT_DIR/privacy-scan.sh"

if [[ ! -x "$SCANNER" ]]; then
  echo "FAIL: scanner not found or not executable: $SCANNER" >&2
  exit 1
fi

# Create temp dirs for test data and private patterns
TESTDIR="$(mktemp -d)"
PRIVATE_DIR="$(mktemp -d)"
trap 'rm -rf "$TESTDIR" "$PRIVATE_DIR"' EXIT

# --- Build neutral private-patterns file ---
cat > "$PRIVATE_DIR/patterns.txt" << 'PATEOF'
# Neutral test patterns
(?<!\w)alice(?!\w)
/home/alice
ExampleChat
PATEOF
export OMARCHY_ALARM_PRIVATE_PATTERNS="$PRIVATE_DIR/patterns.txt"

# --- Helper: concatenate token parts so scanner itself doesn't match ---
GHP="ghp_"
GHP_REST="abcdefghijklmnopqrstuvwxyz1234567890AB"
PAT="github_pat_"
PAT_REST="11AAAAAAAAAAabcdefghij"
ANT="sk-ant-"
ANT_REST="api03-abcdefghijklmnopqrstuvwxyz1234567890abcdef"
OAI="sk-"
OAI_REST="proj-abcdefghijklmnopqrstuvwxyz1234567890"
SLACK="xoxb-"
SLACK_REST="123456789012-123456789012-abcdefghijklmnop"
AKIA_PRE="AKIA"
AKIA_REST="IOSFODNN7EXAMPLE"
GOOG="AIza"
GOOG_REST="SyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q"
GITLAB="glpat-"
GITLAB_REST="xxxxxxxxxxxxxxxxxxxx"
BEARER="bearer"
BEARER_REST=" abcdefghijklmnopqrstuvwxyz123456"
PASS="password="
PASS_REST="supersecretvalue123"

# --- Plant test cases ---
cat > "$TESTDIR/cases.txt" << EOF
# Test cases — all generic rules plus private-pattern rule
# 1. private-pattern (owner username)
alice is the owner
# 2. private-pattern (owner home path)
/home/alice/projects/secret
# 3. private-pattern (app name)
ExampleChat is installed
# 4. email-address
user@realcorp.com
# 5. localhost-author
From: Someone <user@localhost>
# 6. private-key
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA0Z3VS5JJcds3xfn
# 7. github-token
${GHP}${GHP_REST}
# 8. github-pat
${PAT}${PAT_REST}
# 9. anthropic-key
${ANT}${ANT_REST}
# 10. openai-key
${OAI}${OAI_REST}
# 11. slack-token
${SLACK}${SLACK_REST}
# 12. aws-key
${AKIA_PRE}${AKIA_REST}
# 13. google-api-key
${GOOG}${GOOG_REST}
# 14. gitlab-token
${GITLAB}${GITLAB_REST}
# 15. bearer-token
${BEARER}${BEARER_REST}
# 16. password-value
${PASS}${PASS_REST}
# 17. base64-blob (high-entropy: mixed case + digits)
dGhpcyBpcyBhIHZlcnkgbG9uZyBiYXNlNjQgc3RyaW5nMTIzNA
# 18. hex-blob (high-entropy: mixed case + digits)
0123456789ABCDEFabcdef01234567890123456789ABCDEFabcdef
# 19. uuid
550e8400-e29b-41d4-a716-446655440000
# 20. ipv4-address (real IP, not documentation range)
8.8.8.8
# 21. rime-user-data
/test.userdb
# 22. browser-profile-file
Login Data
# 23. absolute-home (not a placeholder)
/home/alice/some/config
EOF

# Plant backup file
touch "$TESTDIR/test.bak"

# Plant Rime userdb file
touch "$TESTDIR/data.userdb"

# --- Run scanner on test dir ---
echo "=== Running selftest ===" >&2
output=""
if output=$(bash "$SCANNER" "$TESTDIR" 2>&1); then
  scan_exit=0
else
  scan_exit=1
fi

# Track failures
failures=0

check_rule() {
  local rule="$1"
  if echo "$output" | grep -q ":${rule}$"; then
    echo "  PASS: $rule" >&2
  else
    echo "  FAIL: $rule not detected" >&2
    failures=$((failures + 1))
  fi
}

# The scanner should have exited 1 (findings detected)
if [[ $scan_exit -eq 0 ]]; then
  echo "  FAIL: scanner exited 0 but expected findings" >&2
  failures=$((failures + 1))
fi

# Check all expected rules
check_rule "private-pattern"
check_rule "email-address"
check_rule "localhost-author"
check_rule "private-key"
check_rule "github-token"
check_rule "github-pat"
check_rule "anthropic-key"
check_rule "openai-key"
check_rule "slack-token"
check_rule "aws-key"
check_rule "google-api-key"
check_rule "gitlab-token"
check_rule "bearer-token"
check_rule "password-value"
check_rule "base64-blob"
check_rule "hex-blob"
check_rule "uuid"
check_rule "ipv4-address"
check_rule "rime-user-data"
check_rule "browser-profile-file"
check_rule "backup-file"
check_rule "rime-userdb-file"
check_rule "absolute-home"

# --- Verify a clean dir passes ---
CLEAN_DIR="$(mktemp -d)"
echo "# clean file" > "$CLEAN_DIR/clean.txt"
echo "nothing sensitive here" >> "$CLEAN_DIR/clean.txt"

# Also test that placeholder paths are allowed
cat > "$CLEAN_DIR/placeholders.txt" << 'EOF'
$HOME/.config/something
~/.local/share/app
/home/$USER/data
/home/${TARGET_USER}/config
EOF

clean_output=""
if clean_output=$(bash "$SCANNER" "$CLEAN_DIR" 2>&1); then
  echo "  PASS: clean dir passes" >&2
else
  echo "  FAIL: clean dir produced findings:" >&2
  echo "$clean_output" >&2
  failures=$((failures + 1))
fi
rm -rf "$CLEAN_DIR"

echo "" >&2
if (( failures > 0 )); then
  echo "Selftest: $failures failure(s)." >&2
  exit 1
else
  echo "Selftest: all rules detected, clean dir passes." >&2
  exit 0
fi
