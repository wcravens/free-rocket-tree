#!/usr/bin/env bash
# Exercises the narrowed protect-subs.sh guard. No writes to subs/ occur here.
set -uo pipefail

GUARD="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/protect-subs.sh}"
export CLAUDE_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

pass=0; fail=0

run() { # name expected(DENY|ALLOW) json
  local name="$1" expected="$2" json="$3" out got
  out=$(printf '%s' "$json" | bash "$GUARD" 2>&1)
  if grep -q '"permissionDecision": *"deny"' <<<"$out"; then got=DENY; else got=ALLOW; fi
  if [[ "$got" == "$expected" ]]; then
    printf '  ok   %-52s %s\n' "$name" "$got"; pass=$((pass+1))
  else
    printf '  FAIL %-52s want %s got %s\n' "$name" "$expected" "$got"; fail=$((fail+1))
  fi
}

bashcall() { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
writecall() { jq -n --arg p "$1" '{tool_name:"Write",tool_input:{file_path:$p}}'; }

echo "== vendored submodule tree stays protected =="
run "bash redirect into submodule"   DENY  "$(bashcall 'echo hi > subs/openrocket/core/x.java')"
run "bash rm inside submodule"       DENY  "$(bashcall 'rm -rf subs/openrocket/core')"
run "bash sed -i inside submodule"   DENY  "$(bashcall 'sed -i "" s/a/b/ subs/openrocket/build.gradle')"
run "bash git checkout in submodule" DENY  "$(bashcall 'git checkout -- subs/openrocket')"
run "bash rm of the submodule dir"   DENY  "$(bashcall 'rm -rf subs/openrocket')"
run "Write tool, relative path"      DENY  "$(writecall 'subs/openrocket/core/x.java')"
run "Write tool, ./ prefixed"        DENY  "$(writecall './subs/openrocket/core/x.java')"
run "Write tool, absolute path"      DENY  "$(writecall "$CLAUDE_PROJECT_DIR/subs/openrocket/x.java")"

echo "== repo-owned notes directly in subs/ are now editable =="
run "Write tool, subs/CLAUDE.md"     ALLOW "$(writecall 'subs/CLAUDE.md')"
run "Write tool, CLAUDE-openrocket"  ALLOW "$(writecall 'subs/CLAUDE-openrocket.md')"
run "Write tool, absolute note path" ALLOW "$(writecall "$CLAUDE_PROJECT_DIR/subs/CLAUDE.md")"
run "bash redirect into subs/ note"  ALLOW "$(bashcall 'cat draft.md > subs/CLAUDE.md')"
run "bash cp into subs/ note"        ALLOW "$(bashcall 'cp /tmp/draft.md subs/CLAUDE.md')"
run "prefix is not a substring match" ALLOW "$(bashcall 'rm subs/openrocket-notes.md')"

echo "== reading is always fine =="
run "bash cat inside submodule"      ALLOW "$(bashcall 'cat subs/openrocket/build.gradle')"
run "bash grep inside submodule"     ALLOW "$(bashcall 'grep -r Barrowman subs/openrocket/core')"
run "Read tool inside submodule"     ALLOW "$(jq -n '{tool_name:"Read",tool_input:{file_path:"subs/openrocket/x.java"}}')"
run "unrelated command"              ALLOW "$(bashcall 'rm -rf docs/scratch')"

echo "== fails closed when .gitmodules is unreadable =="
tmp=$(mktemp -d)
runbare() { # name expected json  -- runs the guard with CLAUDE_PROJECT_DIR=$tmp
  local name="$1" expected="$2" json="$3" out got
  out=$(CLAUDE_PROJECT_DIR="$tmp" bash -c 'printf "%s" "$1" | bash "$2"' _ "$json" "$GUARD" 2>&1)
  if grep -q '"permissionDecision": *"deny"' <<<"$out"; then got=DENY; else got=ALLOW; fi
  if [[ "$got" == "$expected" ]]; then
    printf '  ok   %-52s %s\n' "$name" "$got"; pass=$((pass+1))
  else
    printf '  FAIL %-52s want %s got %s\n' "$name" "$expected" "$got"; fail=$((fail+1))
  fi
}
runbare "no .gitmodules: submodule path"   DENY "$(writecall 'subs/openrocket/x.java')"
runbare "no .gitmodules: guards subs/ note" DENY "$(writecall 'subs/CLAUDE.md')"
runbare "no .gitmodules: bash into subs/"   DENY "$(bashcall 'rm -rf subs/openrocket')"
rmdir "$tmp"

echo
echo "passed: $pass   failed: $fail"
[[ $fail -eq 0 ]]
