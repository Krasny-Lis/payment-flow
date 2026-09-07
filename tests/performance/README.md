# PaymentFlow performance tests

This test suite measures the PaymentFlow ETL and reporting layer with larger
data volumes. It also verifies that higher volume does not change the expected
business behaviour.

## Test scope

- CSV generation for 100,000 and 1,000,000 transactions
- SSIS end-to-end execution time and throughput
- duplicate import and idempotency
- row-count reconciliation and data-quality checks
- reporting procedure latency for four filter scenarios
- logical reads, CPU time and execution plans
- comparison before and after adding performance indexes

## Safety and prerequisites

- Run the tests on a local development database, not on production.
- Keep at least 5 GB of free disk space for CSV files, staging rows, rejected
  rows, the transaction tables and indexes.
- Do not clear the SQL Server buffer cache. The benchmark deliberately uses
  one warm-up run followed by five measured runs.
- Generated performance CSV files are ignored by Git.

## Test sequence

### 1. Record the environment

Run `01_environment_snapshot.sql` in SQL Server Management Studio and retain
the result. It records the SQL Server edition, database settings, table sizes
and indexes present before the test.

### 2. Generate large input files

Run these commands from the repository root in PowerShell:

```powershell
Measure-Command {
    python .\generator\generate_transactions.py `
        --rows 100000 `
        --seed 100042 `
        --output .\data\input\performance_100k.csv
}

Measure-Command {
    python .\generator\generate_transactions.py `
        --rows 1000000 `
        --seed 1000042 `
        --output .\data\input\performance_1m.csv
}

Get-Item .\data\input\performance_*.csv |
    Select-Object Name, Length, LastWriteTime
```

Different seeds are important because they generate different transaction
identifiers. This prevents one test file from being rejected as a duplicate of
another test file.

### 3. Run the 100,000-row ETL test

In the SSIS package:

1. Set the `CM_CSV_PaymentTransactions` connection string to
   `data\input\performance_100k.csv`.
2. Set the `SourceFileName` package variable to `performance_100k.csv`.
3. Run `LoadPaymentTransactions.dtsx`.
4. Run `02_etl_execution_metrics.sql` and record the latest row.

Run the same package a second time without changing the file. The second run
must insert zero transactions and reject all 100,000 rows with the
`ALREADY_IMPORTED` code.

### 4. Run the 1,000,000-row ETL test

Change both SSIS values to `performance_1m.csv`, execute the package once and
run `02_etl_execution_metrics.sql` again.

Then run `03_large_volume_validation.sql`. Every validation row should return
`PASS`.

### 5. Measure the reporting baseline

Open `04_reporting_benchmark.sql`, leave `@TestLabel` set to
`baseline`, and execute the script. It runs four scenarios once as a warm-up
and five times for measurement.

The Messages tab contains SQL Server CPU time and logical reads because the
script enables `SET STATISTICS TIME` and `SET STATISTICS IO`. The Results tab
contains minimum, average and maximum duration in milliseconds.

Run `05_capture_reporting_plan.sql` with **Include Actual Execution Plan**
enabled in SSMS (`Ctrl+M`). Save the execution plan as
`reporting-baseline.sqlplan` outside the repository or capture a screenshot of
the important operators.

### 6. Add the candidate indexes

Run:

```text
database/migrations/05_create_performance_indexes.sql
```

The script is idempotent and can safely be executed more than once.

### 7. Measure the optimized version

In `04_reporting_benchmark.sql`, change:

```sql
DECLARE @TestLabel varchar(50) = 'baseline';
```

to:

```sql
DECLARE @TestLabel varchar(50) = 'optimized';
```

Run the benchmark again. The final result set compares all labels stored in
`audit.QueryPerformanceBenchmark`.

Capture the execution plan again and run `06_index_usage.sql`. The index usage
query requires permission to read SQL Server dynamic management views.

### 8. Record the result

Copy the measured values into `results-template.md`. Keep the baseline and
optimized numbers from the same machine and SQL Server instance.

## Pass criteria

The large-volume test is successful when:

- the ETL execution completes with `SUCCEEDED`;
- `RowsRead = RowsInserted + RowsRejected`;
- the first import inserts the expected number of rows;
- the repeated import inserts zero rows and rejects every duplicate;
- no transaction has an invalid amount or missing status history;
- no successful ETL execution leaves rows in `PENDING` state;
- all report scenarios return data without errors;
- the optimized benchmark is compared with the baseline using measured values.

Performance results depend on CPU, memory, storage and cache state. Therefore,
the repository should report measured values and environment details rather
than claim a universal execution-time threshold.
