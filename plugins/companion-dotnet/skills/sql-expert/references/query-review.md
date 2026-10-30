# SQL review checklist

## Correctness
- [ ] JOIN conditions complete (no accidental cross join / duplicate rows)
- [ ] NULL semantics handled (`NOT IN` with NULLs, `= NULL`, `COUNT(col)` vs `COUNT(*)`)
- [ ] Date ranges half-open: `>= @start AND < @end`
- [ ] Rounding/precision for money and quantities
- [ ] Transactions cover all steps that must succeed together; errors rethrown

## Performance
- [ ] Predicates SARGable; parameter and column types match
- [ ] Supporting indexes exist for JOIN/WHERE/ORDER BY; no unnecessary `DISTINCT`/`ORDER BY`
- [ ] No scalar UDFs / multi-statement TVFs in hot queries (SQL < 2019)
- [ ] Paging uses `OFFSET/FETCH` with deterministic `ORDER BY` or keyset paging for deep pages
- [ ] Temp table vs table variable chosen deliberately; large sets → temp table with index

## Safety & deployment
- [ ] Script idempotent and re-runnable
- [ ] Backward compatible with the currently deployed app version (expand → migrate → contract)
- [ ] Large data changes batched (`TOP (n)` loops) to limit log growth and locking
- [ ] Rollback script provided
- [ ] Permissions: least privilege; no `EXECUTE AS OWNER` without reason
