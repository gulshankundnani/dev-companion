#!/bin/sh
# companion-guard: approve file changes once per conversation.
#   guard.sh check     (PreToolUse)  - ask on the first edit of a session; allow once that session is approved
#   guard.sh approved  (PostToolUse) - an edit ran, so the user approved it: remember this session
# Sessions are tracked as empty marker files named by session_id; markers older than 7 days are pruned.

input=$(cat)
sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
dir="$HOME/.claude/companion-guard"

case "$1" in
  approved)
    [ -n "$sid" ] || exit 0
    mkdir -p "$dir" && : > "$dir/$sid"
    find "$dir" -type f -mtime +7 -delete 2>/dev/null
    ;;
  check)
    if [ -n "$sid" ] && [ -f "$dir/$sid" ]; then
      printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"companion-guard: file changes already approved in this conversation"}}'
    else
      printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"companion-guard: first file change in this conversation. Approve to allow file changes for the rest of it."}}'
    fi
    ;;
esac
exit 0
