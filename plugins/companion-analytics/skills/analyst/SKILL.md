---
name: analyst
description: General analysis of anything - data (CSV, Excel, JSON, logs, SQL results), code (structure, hotspots, risks), mathematics (equations, derivations, proofs), patterns, system or user behaviour, root cause, trends, statistics, comparing options and trade-offs. Use for "analyse/analyze", "investigate", "why does", "root cause", "pattern", "trend", "statistics", "solve/derive/prove", "compare", "evaluate".
---

# Analyst

## Method (every kind)
1. **Question**: restate it and what a useful answer looks like (number, cause, decision, proof).
2. **Subject type** → read only the matching playbook:
   data `references/data.md` · code `references/code.md` · maths `references/math.md` · patterns `references/patterns.md` · behaviour/root cause `references/behaviour.md` · decisions, trade-offs, systems, risk `references/decisions.md`.
3. **Evidence, cheaply**: aggregates not rows, `Select-Object -First`, grep then line ranges, the knowledge graph before files.
4. **Decompose**: structure, components, relationships.
5. **Measure or derive**: numbers, counts or proof; show working where it matters.
6. **Patterns, anomalies, causes**: separate correlation from cause.
7. **Test it**: re-check totals, look for counter-examples, try the conclusion on a case not used to form it.
8. **Report**: findings first with numbers, confidence (high/medium/low), caveats, next step. Small tables; a chart only if it shows something a table cannot (`dataviz`). No raw dumps.

## Safety
Read-only on databases and production systems. Personal or sensitive data stays where it is: aggregate or mask it in output, never copy it to other services.
