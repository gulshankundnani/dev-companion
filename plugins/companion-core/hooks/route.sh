#!/bin/sh
# UserPromptSubmit hook: decide which companion skills this request needs.
# Anything printed stays in the conversation and is re-read on every later API call, so the hook
# prints only when it adds value:
#   - Required skills: domain experts on requests that change code, and specialists for explicit
#     actions (commit/PR, tests, docs, "remember", retro). Questions get nothing (analysis questions get the analyst); Claude decides
#     from the skill descriptions. Each skill is named once per conversation, max 2 per prompt.
#   - A one-time nudge to /compact when the context grows past ~130k and ~170k tokens.
# The workflow skill is never auto-loaded: its essentials are already in the always-on rules.

input=$(cat)
prompt=$(printf '%s' "$input" | sed -n -E 's/.*"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1 | tr 'A-Z' 'a-z')
sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

dir="$HOME/.claude/companion-router"
state="$dir/${sid:-none}"

# Slash commands (/compact, /clear, skills) and harness notifications (background task finished)
# are not user requests: no routing
# Continuation summaries after a compaction recap everything and would match every rule.
case "$prompt" in /*|*'<task-notification>'*|*'[system notification'*|'this session is being continued from a previous conversation'*|'<artifact-content-authored-by-others/>'*) exit 0 ;; esac

# Context-size nudge: every API call re-reads the whole conversation, so a large context is the
# main cost driver. Read the latest context size from the transcript; nudge once at ~130k and ~170k.
tp=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr '\134' '/' | sed 's#//*#/#g')   # JSON-escaped Windows path -> C:/Users/...
if [ -n "$sid" ] && [ -f "$tp" ]; then
  last=$(tail -n 300 "$tp" | grep '"cache_read_input_tokens"' | tail -n 1)
  num() { printf '%s' "$last" | grep -o "\"$1\":[0-9]*" | tail -n 1 | grep -o '[0-9]*$'; }
  ctx=$(( $(num input_tokens || echo 0) + $(num cache_creation_input_tokens || echo 0) + $(num cache_read_input_tokens || echo 0) ))
  level=0
  [ "$ctx" -ge 130000 ] && level=130
  [ "$ctx" -ge 170000 ] && level=170
  if [ "$level" -gt 0 ] && ! grep -qx "ctx:$level" "$state" 2>/dev/null; then
    mkdir -p "$dir" && echo "ctx:$level" >> "$state"
    echo "[companion] Context ~$((ctx / 1000))k tokens, re-read every call. If the earlier task is done, tell the user in one line that /compact or a new session cuts cost; if unfinished, offer to save a handoff first."
  fi
fi

# Very short prompts ("yes", "test it") need no skill routing
[ "${#prompt}" -lt 20 ] && exit 0

has() { printf '%s' "$prompt" | grep -Eq "$1"; }
required=""
need() { required="$required $1"; }

# Analysis intent counts as work even when phrased as a question ("what is the trend in X?").
# Bare "pattern" also means "follow the existing pattern", so it needs "in/of" or "find".
analysis=0
has '(\banaly[sz](e|es|ed|ing|is)\b|\binvestigat|\bwhy (does|do|did|is|are|was)\b|root cause|\bpatterns? (in|of|across)\b|find .{0,20}pattern|recurring|\btrends?\b|\bbehaviou?r|\bstatistic|\b(derive|solve|prove)\b|\bcompare\b|\bevaluate\b)' && analysis=1

# Questions get no routing (analysis questions get only the analyst). An explicit change verb wins;
# otherwise anything that doesn't read like a question is treated as work (bug reports, task titles).
question=0
if ! has '\b(implement|add|create|build|fix|refactor|migrate|feature|plan|change|upgrade|optimi[sz]e|rewrite|rename)\b'; then
  has '(^(what|why|how|where|which|who|when|is|are|does|do|did|can you explain|explain|tell me)\b|\?[[:space:]]*$)' && question=1
fi
# Locating things also counts even as a question ("where is the fee receipt view?")
finding=0
has '(\bwhere (is|are|do|does)\b|\blocate\b|which (file|folder|view|controller|table|proc)|\bfind (the |all |where |which )?(files?|folders?|class|method|function|view|controller|proc|table|usages?|references?|callers?)\b|search (for|the code|the project))' && finding=1
[ "$question" -eq 1 ] && [ "$analysis" -eq 0 ] && [ "$finding" -eq 0 ] && exit 0
# Requests about skills, plugins or hooks name domains in passing ("analyse CSV, JSON, SQL results"):
# they get no domain expert
experts=1
{ [ "$question" -eq 1 ] || has '(\bskills?\b|\bplugins?\b|\bhooks?\b|\brouter\b)'; } && experts=0

# Domain experts
if [ "$experts" -eq 1 ]; then
has '(\.cs\b|c#|csharp|\.net\b|dotnet|asp\.net|entity framework|\bef( core)?\b|linq|nuget|\bwpf\b|winforms|\.csproj|controller|viewmodel)' && need companion-dotnet:csharp-expert
# SQL: only unambiguous database terms. Bare "index", "table", "column", "query" also mean
# Index.cshtml, HTML tables, grid columns and LINQ, so they need a database word next to them.
# Bare "sql" is often a passing mention ("CSV, JSON, SQL results"), so it needs an action or an object.
has '((write|fix|optimi[sz]e|tune|debug|review|change|update|correct)\b[^.]{0,30}\bsql\b|\bsql (query|queries|script|file|statement|server|job|procedure|function|view|trigger|table|column)|t-sql|stored proc|\bprocedure\b|database|\bdb\b|\bschema\b|deadlock|migration|execution plan|(create|alter|drop) (unique |clustered |nonclustered )?(table|index|view)|index (on|scan|seek)|missing index|\bindexes\b|(db|database|sql) (table|column|query)|(slow|sql) query|foreign key|primary key)' && need companion-dotnet:sql-expert
# Front end in MVC apps: Razor views, JavaScript/jQuery, popups
has '(\.cshtml|razor|partial view|\.js\b|javascript|jquery|\bajax\b|popup|pop-up|modal|dialog|bootstrap|\bdom\b|z-index)' && need companion-ui:web-frontend-expert
has '(\bui\b|\bux\b|mockup|wireframe|prototype|\blayout|\bcss\b|accessib|usability|look and feel|redesign)' && need companion-ui:ui-ux-expert
has '(\bslow\b|performance|optimi[sz]|clean ?up|clean code|code quality|simplif|readab|maintainab)' && need companion-core:clean-code
fi
# After the domain experts: on a change request they keep priority within the 2-skill limit
[ "$finding" -eq 1 ] && need companion-core:find
[ "$analysis" -eq 1 ] && need companion-analytics:analyst

# Specialists for explicit actions
[ "$question" -eq 1 ] || {
has '(\btests?\b|testing|security|vulnerab|owasp|\bxss\b|csrf|injection|brute.?force|penetration|\bidor\b|unit test|coverage|xunit|nunit|mstest|jest|playwright)' && need companion-core:testing-expert
has '(\bcommit|\bbranch|pull request|\bpr\b|\bmerge\b|shelve|check ?in|\btfs\b|tfvc)' && need companion-core:git-tfs
has '(readme|release notes|document(ation)?\b)' && need companion-core:documentation
has '(remember (that|this)|from now on|initiali[sz]e (project )?memory)' && need companion-core:project-memory
has '(\bretro\b|learn from this|do not do that again|don.t do that again)' && need companion-core:learning-loop
has '(hand ?off|handover|resume (the |my )?(task|work|handoff)|save (the )?(progress|session|task state)|(other|another|different) (login|account)|(usage|rate|token) limit|out of tokens|tokens? (are )?maxed)' && need companion-core:handoff
has '(background (task|job|script|process|usage|token)|in (the )?background|\bpolling\b|idle tokens|what is using (my )?tokens)' && need companion-core:background-usage
}

[ -n "$required" ] || exit 0

req=""; n=0
for s in $required; do
  [ -n "$sid" ] && [ -f "$state" ] && grep -qx "$s" "$state" && continue
  [ "$n" -ge 2 ] && break
  req="$req $s"; n=$((n + 1))
done
[ -n "$req" ] || exit 0

echo "[companion] Required: invoke the Skill tool for each of these before any other tool:$req"
if [ -n "$sid" ]; then
  mkdir -p "$dir"
  for s in $req; do echo "$s" >> "$state"; done
  find "$dir" -type f -mtime +7 -delete 2>/dev/null
fi
exit 0
