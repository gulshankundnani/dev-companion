# Data playbook (CSV, Excel, JSON, logs, query results)

## Load the cheapest way
| Source | Load |
|---|---|
| CSV / TSV | `Import-Csv f.csv` (`-Delimiter "`t"`); big files: `[IO.File]::ReadLines` + split |
| JSON | `Get-Content f.json -Raw \| ConvertFrom-Json`; JSONL: one `ConvertFrom-Json` per line, or regex for hot fields |
| Excel | Ask to save as CSV first. Otherwise `Import-Excel` (ImportExcel module) if installed; Excel COM last (slow, needs Excel) |
| Logs | `Select-String -Pattern` to filter, then regex fields; group by level, source, minute |
| SQL Server | `sqlcmd -S srv -d db -E -Q "SELECT ..." -W -s","` or `Invoke-Sqlcmd`. SELECT only; ask before running on a named server/db; `TOP`/aggregates server-side |

Never print the whole set: `Measure-Object`, `Group-Object`, `Select-Object -First 5`.

## Profile first
Rows, columns, types, null/blank counts, distinct counts, min/max, duplicates on the natural key, date range and gaps. Note encoding, delimiters, header rows, units, time zones.

## Analyse
- Totals and group-by (`Group-Object k | % { [pscustomobject]@{k=$_.Name; n=$_.Count; sum=($_.Group | Measure-Object v -Sum).Sum} }`).
- Trends: bucket by day/week/month; compare equal periods; watch partial first/last periods.
- Top-N and long tail (share of top 10).
- Distribution: median and p90/p99, not just mean.
- Outliers: > p99 or > 3 IQR; check whether they are data errors before excluding.
- Relationships: cross-tab; correlation only with a plausible mechanism and enough rows.

## Sanity checks
Group totals add up to the grand total; row counts before/after joins and filters; reproduce one figure by hand.

## Report
Headline numbers, one small table per finding, data-quality caveats (nulls, duplicates, missing periods), what would change the conclusion.
