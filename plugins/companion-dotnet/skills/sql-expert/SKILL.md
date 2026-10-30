---
name: sql-expert
description: SQL Server/T-SQL first (also PostgreSQL, MySQL, Oracle) - schema design, indexing, query tuning, procs, transactions, safe migrations and data fixes. Use when writing or reviewing SQL or migrations, or diagnosing slow queries, deadlocks or data issues.
---

# DB / SQL

**Safety**: never run DDL/DML against a database without consent naming the server and database. Data fixes: `SELECT` preview, dry run in `BEGIN TRAN … ROLLBACK`, row counts, commit on approval, rollback script. No credentials in code or notes. Destructive migrations need a data-preservation plan.

**Test first**: run new or changed queries in `BEGIN TRAN ... ROLLBACK` or on temp tables with sample rows before editing scripts or procs; compare row counts and results with the old version.

**Context**: engine/version, compatibility level, and how schema is managed (SSDT, EF migrations, DbUp/Flyway, scripts) - follow it. Check `graph.md` for dependents first.

**T-SQL**
- Readable: one clause per line, meaningful aliases (`o` for Orders, not `t1`), CTEs to name steps instead of nested subqueries, explicit `JOIN ... ON`, comments for business rules only.
- Explicit columns, schema-qualified names (`dbo.Orders`); set-based, not cursors.
- SARGable: no functions on indexed columns (use ranges), matching types (no implicit conversion).
- Parameterised; dynamic SQL only via `sp_executesql` + `QUOTENAME`.
- Procs: `SET NOCOUNT ON; SET XACT_ABORT ON;`, `TRY…CATCH` + `THROW`, short transactions.
- Idempotent scripts: `CREATE OR ALTER`, `IF NOT EXISTS` guards. `NOLOCK` only if dirty reads are accepted.

**Schema**: 3NF by default; `decimal(19,4)` money, `datetime2`, sized `nvarchar`; PK on every table, indexed FKs, `NOT NULL`/`CHECK`/`UNIQUE` constraints.

**Tuning** (measure first): actual plan + `STATISTICS IO, TIME`/Query Store → look for scans, key lookups, implicit conversions, bad estimates, parameter sniffing → fix by rewrite, then covering/filtered index, then statistics, hints last. Weigh index write cost; report before/after reads.

**Concurrency**: consistent access order, right isolation level, `UPDLOCK, HOLDLOCK` for upserts; deadlock graphs from `system_health`.

Review list: `references/query-review.md` (read only when reviewing). Record new objects in `graph.md`.
