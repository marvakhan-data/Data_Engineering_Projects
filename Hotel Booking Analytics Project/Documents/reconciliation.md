# Reconciliation

## Formula

```
bronze_rows = clean_rows + rejected_rows + duplicate_rows
```

## Reference result

| Bronze rows | Clean rows | Rejected rows | Duplicates removed | Total accounted | Difference |
|------------:|-----------:|--------------:|-------------------:|----------------:|-----------:|
| 1,316 | 1,269 | 21 | 26 | 1,316 | 0 |

1,269 + 21 + 26 = 1,316 (passed)

## How it is proven

The `gold_data_quality` table returns `accounted_rows`, `difference` and `reconciliation_passed`.
The check passes only when `difference = 0`.

## Why it can fail (and what to check)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| difference > 0 (rows missing) | A row is dropped by an expectation but is not in the rejected table (e.g. NULL `booking_id` or NULL dates) | Add that condition to `silver_bookings_rejected` |
| difference < 0 (rows counted twice) | A duplicated bad booking appears twice in the rejected table | Deduplicate the rejected view by `booking_id` |
| Duplicates not removed | Copies differ by spaces or case, so `SELECT DISTINCT` misses them | Deduplicate on `TRIM(booking_id)` with `ROW_NUMBER()` |
| Bronze rows is not 1,316 | Wrong file, header issue, or file loaded twice | Check `source_file` and the volume contents |

