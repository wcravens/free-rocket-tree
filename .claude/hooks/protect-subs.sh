#!/usr/bin/env bash
# PreToolUse guard: keep vendored third-party source under subs/ read-only.
#
# Permission deny rules cover Edit/Write/NotebookEdit but NOT Bash, which is the
# primary edit path for many agent sessions. This closes that gap on a
# best-effort basis. It is a guard against accidents, not a security boundary --
# a determined caller can obfuscate a command past any text inspection.
set -uo pipefail

input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

REASON='subs/ holds vendored OpenRocket source pinned for citation accuracy and is read-only. Reading is fine; writing is not. For genuine submodule maintenance (update, re-pin), run the git command yourself with the ! prefix.'

# Bash, plus any MCP tool that takes a shell command (e.g. serena execute_shell_command).
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
if [[ "$tool" == "Bash" || -n "$cmd" ]]; then

  # Only inspect commands that reference subs/ at all.
  grep -qE '(^|[^[:alnum:]_./-])\.?/?subs/' <<<"$cmd" || exit 0

  # Mutating verbs anywhere in a command that touches subs/.
  if grep -qE '(^|[^[:alnum:]_-])(rm|mv|cp|touch|tee|install|truncate|dd|mkdir|rmdir|ln|chmod|chown|patch)([^[:alnum:]_-]|$)' <<<"$cmd" \
  || grep -qE '(sed|perl|ruby)[[:space:]]+[^|;&]*-i' <<<"$cmd" \
  || grep -qE 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(checkout|apply|reset|clean|add|commit|rm|mv|restore|stash|submodule[[:space:]]+(update|add|deinit))' <<<"$cmd" \
  || grep -qE '>[[:space:]]*\.?/?subs/' <<<"$cmd"; then
    deny "$REASON"
  fi
  exit 0
fi

# Path-bearing WRITE tools only -- reading vendored source is the whole point of
# having it, so Read/Grep/Glob must pass through untouched.
if ! grep -qE '^(Write|Edit|MultiEdit|NotebookEdit)$|(create_text_file|replace_content|replace_symbol_body|replace_in_files|insert_(after|before)_symbol|rename_symbol|safe_delete_symbol)' <<<"$tool"; then
  exit 0
fi

path=$(jq -r '
  [.tool_input.file_path?, .tool_input.path?, .tool_input.relative_path?, .tool_input.notebook_path?]
  | map(select(. != null and . != "")) | .[0] // ""
' <<<"$input")
[[ -n "$path" ]] || exit 0

# Normalise: strip a leading project-root prefix, then a leading ./
root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${path#"$root"/}"
rel="${rel#./}"
[[ "$rel" == subs/* ]] && deny "$REASON"

exit 0
