#!/usr/bin/env bash
# PreToolUse guard: keep vendored third-party source under subs/ read-only.
#
# Scope: the submodule directories recorded in .gitmodules (e.g. subs/openrocket).
# This repo's own notes that sit directly in subs/ -- subs/CLAUDE.md and
# friends -- are deliberately NOT covered; they are ours to edit.
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

REASON='That path is inside a vendored submodule under subs/, which is pinned for citation accuracy and read-only. Reading is fine; writing is not. For genuine submodule maintenance (update, re-pin), run the git command yourself with the ! prefix. Note that the notes this repo keeps directly in subs/, such as subs/CLAUDE.md, are outside this guard and may be edited normally.'

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Protected prefixes: the submodule paths under subs/ recorded in .gitmodules.
# Fail closed -- if that file cannot be read, guard the whole directory.
protected=()
while IFS= read -r p; do
  [[ -n "$p" ]] && protected+=("$p")
done < <(git config -f "$root/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
         | awk '{print $2}' | sed 's:/*$::' | grep -E '^subs/[^/]+$')
[[ ${#protected[@]} -gt 0 ]] || protected=("subs")

# Regex alternation over those prefixes, for inspecting shell command text.
alt=""
for p in "${protected[@]}"; do alt="${alt:+$alt|}$p"; done

# Bash, plus any MCP tool that takes a shell command (e.g. serena execute_shell_command).
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
if [[ "$tool" == "Bash" || -n "$cmd" ]]; then

  # Only inspect commands that reference a protected path at all. The trailing
  # class is what keeps subs/openrocket from also matching subs/openrocket.md.
  grep -qE "(^|[^[:alnum:]_./-])\.?/?($alt)([^[:alnum:]_.-]|$)" <<<"$cmd" || exit 0

  # Mutating verbs anywhere in a command that touches a protected path.
  if grep -qE '(^|[^[:alnum:]_-])(rm|mv|cp|touch|tee|install|truncate|dd|mkdir|rmdir|ln|chmod|chown|patch)([^[:alnum:]_-]|$)' <<<"$cmd" \
  || grep -qE '(sed|perl|ruby)[[:space:]]+[^|;&]*-i' <<<"$cmd" \
  || grep -qE 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(checkout|apply|reset|clean|add|commit|rm|mv|restore|stash|submodule[[:space:]]+(update|add|deinit))' <<<"$cmd" \
  || grep -qE ">[[:space:]]*\.?/?($alt)" <<<"$cmd"; then
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
rel="${path#"$root"/}"
rel="${rel#./}"
for p in "${protected[@]}"; do
  [[ "$rel" == "$p" || "$rel" == "$p"/* ]] && deny "$REASON"
done

exit 0
