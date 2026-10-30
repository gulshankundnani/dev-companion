# Code playbook

## Gather
- Knowledge graph first (`.claude/knowledge/graph.md`, `architecture-map`): projects, references, who uses what.
- Then grep for symbols, read line ranges. Size: file/line counts per folder, largest files, method lengths.

## Decompose
- Structure: layers, projects, entry points (controllers, jobs, handlers), data access.
- Dependencies: references in and out, cycles, shared static state, hidden coupling (config keys, session, magic strings).
- Data flow for the question: input -> validation -> logic -> storage -> output.

## Measure
- Complexity: long methods (>50 lines), deep nesting, many parameters, large switch/if chains.
- Hotspots: churn x complexity. Churn from `git log --format= --name-only | sort | uniq -c | sort -rn | head` or TFS history.
- Duplication: same block in 3+ places (`code-reuse`).
- Dead code: no references in the graph or grep, not reflection/DI/route-bound.

## Risks to look for
N+1 and queries in loops, sync-over-async, missing disposal, shared mutable state and race conditions, unbounded caches, string-built SQL, missing authorization, swallowed exceptions, culture/time-zone bugs.

## Why it is like this
`git blame -L a,b file` / `git log -L` / TFS annotate, then the linked work item, before calling something a mistake.

## Report
Findings ranked by impact x likelihood, each with file:line, evidence and a suggested fix; what was not inspected.
