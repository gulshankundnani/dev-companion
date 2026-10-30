#!/bin/sh
# Regression test for plugins/companion-core/hooks/route.sh: feeds each prompt in router-cases.txt
# to the router (no session state) and compares the required skills with the expected ones.
# Usage: sh tools/test-router.sh
root=$(cd "$(dirname "$0")/.." && pwd)
router="$root/plugins/companion-core/hooks/route.sh"
home=$(mktemp -d)
pass=0; fail=0
while IFS='|' read -r expected prompt; do
  case "$expected" in '#'*|'') continue ;; esac
  esc=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')
  got=$(printf '{"prompt":"%s","session_id":""}' "$esc" | HOME="$home" sh "$router" | sed -n 's/.*before any other tool: *//p')
  [ -n "$got" ] || got=-
  if [ "$got" = "$expected" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $prompt"; echo "  expected: $expected"; echo "  got:      $got"; fi
done < "$root/tools/router-cases.txt"
rm -rf "$home"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
