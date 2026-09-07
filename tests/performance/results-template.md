# PaymentFlow large-volume performance results

## Environment

| Property | Value |
|---|---|
| Test date | TBD |
| SQL Server edition and version | TBD |
| Database compatibility level | TBD |
| CPU | TBD |
| Memory | TBD |
| Storage type | TBD |

## Dataset generation

| Rows | Seed | File size | Generation time |
|---:|---:|---:|---:|
| 100,000 | 100042 | TBD | TBD |
| 1,000,000 | 1000042 | TBD | TBD |

## ETL results

| Test | Rows read | Rows inserted | Rows rejected | Duration | Rows/second | Status |
|---|---:|---:|---:|---:|---:|---|
| Initial 100,000-row import | TBD | TBD | TBD | TBD | TBD | TBD |
| Repeated 100,000-row import | TBD | TBD | TBD | TBD | TBD | TBD |
| Initial 1,000,000-row import | TBD | TBD | TBD | TBD | TBD | TBD |
| Indexed-state 100,000-row import 1 | TBD | TBD | TBD | TBD | TBD | TBD |
| Indexed-state 100,000-row import 2 | TBD | TBD | TBD | TBD | TBD | TBD |

## Data validation

| Validation | Expected | Actual | Result |
|---|---:|---:|---|
| Minimum transaction count | >= 1,000,000 | TBD | TBD |
| Duplicate external transaction IDs | 0 | TBD | TBD |
| Transactions with non-positive amount | 0 | TBD | TBD |
| Transactions without status history | 0 | TBD | TBD |
| Successful ETL count mismatches | 0 | TBD | TBD |
| Pending rows from successful executions | 0 | TBD | TBD |

## Reporting benchmark

| Scenario | Baseline average ms | Optimized average ms | Change |
|---|---:|---:|---:|
| Full year - all filters | TBD | TBD | TBD |
| January - all filters | TBD | TBD | TBD |
| Full year - one merchant | TBD | TBD | TBD |
| Full year - Poland and PLN | TBD | TBD | TBD |

## Execution-plan observations

- Baseline access method: TBD
- Optimized access method: TBD
- Most expensive baseline operator: TBD
- Most expensive optimized operator: TBD
- Logical reads before and after: TBD

## Rejected index experiment

| Scenario | Existing index ms | Candidate index ms | Change | Decision |
|---|---:|---:|---:|---|
| Full year - all filters | TBD | TBD | TBD | TBD |
| January - all filters | TBD | TBD | TBD | TBD |
| Full year - one merchant | TBD | TBD | TBD | TBD |
| Full year - Poland and PLN | TBD | TBD | TBD | TBD |

## Index maintenance

| Measurement | Before rebuild | After rebuild | Change |
|---|---:|---:|---:|
| Leaf page count | TBD | TBD | TBD |
| Fragmentation | TBD | TBD | TBD |
| Page-space usage | TBD | TBD | TBD |

| Scenario | Fragmented average ms | Rebuilt average ms | Change |
|---|---:|---:|---:|
| Full year - all filters | TBD | TBD | TBD |
| January - all filters | TBD | TBD | TBD |
| Full year - one merchant | TBD | TBD | TBD |
| Full year - Poland and PLN | TBD | TBD | TBD |

## Integrity check

| Check | Result |
|---|---|
| `DBCC CHECKDB` | TBD |

## Conclusion

TBD: summarize correctness, ETL throughput, report latency and the measurable
effect of the added indexes. Mention that the results apply to the environment
recorded above.
