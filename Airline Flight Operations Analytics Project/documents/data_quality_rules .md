<div align="center">

# 🧪 Data Quality Rules

**Airline Flight Operations Analytics Platform**

![Rules](https://img.shields.io/badge/Rules-13-blue?style=flat-square)
![Layers](https://img.shields.io/badge/Layers-Bronze%20%7C%20Silver%20%7C%20Gold-orange?style=flat-square)
![Reconciliation](https://img.shields.io/badge/Reconciliation-1%2C365%20%3D%201%2C321%20%2B%2019%20%2B%2025-brightgreen?style=flat-square)

</div>

Source file: `airline_flights_raw.csv` (1,365 rows, 20 columns, synthetic 2025 domestic flights)
Pipeline: Lakeflow Spark Declarative Pipelines (SQL), Medallion Architecture
Location: `aviation_catalog.flights`

[← Back to README](../README.md)

## 🔄 How Rows Flow Through the Rules

![pipeline](/images/pipeline_lineage.png)
---
## 1. 🎯 Purpose

These rules define how the raw flights file is checked, cleaned, rejected or kept, so that every Gold table and dashboard number can be trusted and explained. Each rule has an ID, a layer, an action and a SQL approach.

**Actions used**

| Action | Meaning |
|---|---|
| **Keep** | Load as is, no change |
| **Fix** | Correct the value and keep the row |
| **Fill** | Replace a blank with a derived or default value and keep the row |
| **Remove** | Drop an extra copy (duplicate) |
| **Reject** | Remove from clean table and save in the rejected table with a reason |
| **Count** | Measure how often the problem occurs (Gold data-quality table) |

---

## 2. Rule Summary

| ID | Problem | Layer | Action | Expected rows (reference solution) |
|---|---|---|---|---|
| DQ-01 | Raw file must load completely | Bronze | Keep | 1,365 |
| DQ-02 | Duplicate flights (same `flight_id`) | Silver | Remove | 25 |
| DQ-03 | Extra spaces and mixed capital letters | Silver | Fix | n/a (all text columns) |
| DQ-04 | Blank airline | Silver | Fill with `Unknown` | 11 |
| DQ-05 | Blank delay reason | Silver | Fill with `Unknown` | 12 |
| DQ-06 | Blank delay minutes | Silver | Fill from timestamps | 18 |
| DQ-07 | Blank ticket revenue | Silver | Fill with passengers x avg_fare | 16 |
| DQ-08 | Blank aircraft ID | Silver | Keep | n/a |
| DQ-09 | Passengers more than seats | Silver | Reject | 11 |
| DQ-10 | Negative average fare | Silver | Reject | 8 (19 total rejected with DQ-09) |
| DQ-11 | Negative delay minutes (left early) | Silver | Keep, category On Time | n/a |
| DQ-12 | Every clean flight has a delay category | Silver | Derive | 1,321 |
| DQ-13 | Reconciliation | Gold | Count and check | Bronze = Clean + Rejected + Duplicates |

Reference counts come from the example dashboard in the project document. Your own counts should match them if the rules are applied exactly as written.

---

## 3. Detailed Rules

### DQ-01: Complete load into Bronze
- **Rule:** Bronze keeps the CSV exactly as received. Only two audit columns are added: `source_file` and `loaded_at`.
- **Why:** Raw data is the proof of what was received. Cleaning later must never change it.
- **Check:** `SELECT COUNT(*) FROM bronze_airline_flights` returns **1,365**.

```sql
CREATE OR REFRESH STREAMING TABLE bronze_airline_flights AS
SELECT *,
       _metadata.file_name AS source_file,
       current_timestamp() AS loaded_at
FROM STREAM read_files('/Volumes/aviation_catalog/flights/raw_files/',
                       format => 'csv', header => true);
```

### DQ-02: Remove duplicate flights
- **Rule:** `flight_id` identifies one flight on one day. If the same `flight_id` appears more than once, keep one copy and remove the rest.
- **Do not** use `flight_number` to find duplicates. The same flight number runs on many days.
- **Why:** Duplicates inflate flights, passengers and revenue.
- **SQL approach:** `SELECT DISTINCT` on the cleaned columns (works when duplicates are exact copies).
- **Count:** `COUNT(*) - COUNT(DISTINCT flight_id)` = **25** duplicates.

### DQ-03: Standardise text
- **Applies to:** `airline`, `origin_city`, `destination_city`, `delay_reason`.
- **Rule:** Remove leading and trailing spaces, then convert to Title Case.
- **Examples:** `" sky jet"` becomes `Sky Jet`, `"DELHI"` becomes `Delhi`, `" weather "` becomes `Weather`.
- **SQL:** `INITCAP(TRIM(col))`
- **Pass condition:** `COUNT(DISTINCT airline)` returns only the five brands plus `Unknown`. No value has leading or trailing spaces.

### DQ-04: Blank airline
- **Rule:** Replace a blank airline with `Unknown`. Keep the row.
- **SQL:** `COALESCE(NULLIF(INITCAP(TRIM(airline)), ''), 'Unknown')`
- **Why `NULLIF`:** A value made only of spaces is not NULL, but becomes an empty string after `TRIM`. `NULLIF(..., '')` turns it into NULL so `COALESCE` can catch it.

### DQ-05: Blank delay reason
- **Rule:** Replace a blank delay reason with `Unknown`. Keep the row.
- **Note:** `None` is a valid business value (no delay reason) and is **not** the same as blank. Do not change `None` to `Unknown`.
- **SQL:** `COALESCE(NULLIF(INITCAP(TRIM(delay_reason)), ''), 'Unknown')`

### DQ-06: Blank delay minutes
- **Rule:** Calculate from the two departure times.
- **SQL:** `COALESCE(delay_minutes, TIMESTAMPDIFF(MINUTE, scheduled_departure, actual_departure))`
- **Order matters:** The first argument is scheduled, the second is actual. Swapping them flips the sign, so late flights look early and are wrongly labelled On Time.
- **Pass condition:** No NULL `delay_minutes` in Silver clean.

### DQ-07: Blank ticket revenue
- **Rule:** Calculate passengers x average fare.
- **SQL:** `COALESCE(ticket_revenue, passengers * avg_fare)`
- **Pass condition:** No NULL `ticket_revenue` in Silver clean.

### DQ-08: Blank aircraft ID
- **Rule:** Keep the row unchanged. Aircraft ID is not needed for any Gold metric, and revenue is still valid.

### DQ-09: Passengers more than seats (impossible load)
- **Rule:** A flight is invalid if `passengers > seat_capacity` or `passengers < 0`.
- **Action:** Remove from `silver_flights_clean` and save in `silver_flights_rejected` with reason `Passengers more than seats`.
- **Enforcement:**

```sql
CONSTRAINT valid_passengers EXPECT (passengers BETWEEN 0 AND seat_capacity) ON VIOLATION DROP ROW
```

### DQ-10: Negative average fare
- **Rule:** A flight is invalid if `avg_fare < 0`.
- **Action:** Remove from clean, save in rejected with reason `Average fare is negative`.
- **Enforcement:**

```sql
CONSTRAINT valid_fare EXPECT (avg_fare >= 0) ON VIOLATION DROP ROW
```

### DQ-11: Negative delay is valid
- **Rule:** A negative `delay_minutes` means the flight left early. This is **not** bad data. It is kept and counted as **On Time**.
- **Why:** On Time means a delay of 15 minutes or less.

### DQ-12: Delay category
Every clean flight must have exactly one category.

| `delay_minutes` | `delay_category` |
|---|---|
| 15 or less (including negative) | On Time |
| 16 to 60 | Minor Delay |
| More than 60 | Major Delay |

```sql
CASE WHEN delay_minutes <= 15 THEN 'On Time'
     WHEN delay_minutes <= 60 THEN 'Minor Delay'
     ELSE 'Major Delay' END AS delay_category
```

**Pass condition:** On Time + Minor Delay + Major Delay = clean rows (1,321). No NULL category.

### DQ-13: Reconciliation
- **Rule:** Every input row must be accounted for.

```
bronze_rows = clean_rows + rejected_rows + duplicate_rows
1,365       = 1,321      + 19            + 25
```

- **Where:** `gold_data_quality`
- **Also check:** The dashboard Total Flights card equals `clean_rows` (1,321).

---

## 4. Rejected Table Contract

`silver_flights_rejected` must:

1. Contain every column from Bronze plus `reject_reason`.
2. Never be empty of a reason. Every row has a non-NULL `reject_reason`.
3. Use one of these reasons:
   - `Passengers more than seats`
   - `Average fare is negative`
4. Hold one row per rejected flight (see the implementation notes below).

---

## 5. Gold Data Quality Table (`gold_data_quality`)

Columns to produce (counted on Bronze so problems are measured before they are fixed):

| Column | Definition |
|---|---|
| `bronze_rows` | `COUNT(*)` |
| `duplicate_rows` | `COUNT(*) - COUNT(DISTINCT flight_id)` |
| `overbooked_rows` | passengers > seat_capacity |
| `negative_fare_rows` | avg_fare < 0 |
| `missing_airline_rows` | airline blank or NULL |
| `missing_delay_rows` | delay_minutes blank or NULL |
| `missing_revenue_rows` | ticket_revenue blank or NULL |
| `missing_reason_rows` | delay_reason blank or NULL |
| `clean_rows` | `COUNT(*)` from `silver_flights_clean` |
| `rejected_rows` | `COUNT(*)` from `silver_flights_rejected` |
| `reconciliation_passed` | `bronze_rows = clean_rows + rejected_rows + duplicate_rows` as Yes/No |

---

## 6. Implementation Notes and Pitfalls

These are small gaps in the starter snippets that are worth fixing in your solution.

1. **Blank vs spaces.** `COALESCE(INITCAP(TRIM(col)), 'Unknown')` only catches true NULLs. Use `NULLIF(TRIM(col), '')` first so whitespace-only values are also treated as blank.
2. **Reject reason for negative passengers.** The starter `CASE` only has two branches, so a row with `passengers < 0` would be labelled "Average fare is negative". Add a branch, for example `WHEN passengers < 0 THEN 'Passengers negative'`, or confirm your data has none.
3. **Duplicates inside the rejected table.** The starter rejected query reads Bronze without `DISTINCT`. If a bad flight is also duplicated, it would be counted in both `rejected_rows` and `duplicate_rows`, and the reconciliation would not balance. Use `SELECT DISTINCT` (or deduplicate by `flight_id`) in the rejected table too.
4. **Duplicates are only exact copies.** `SELECT DISTINCT` removes a duplicate only if every selected column matches. If two rows share a `flight_id` but differ slightly (for example one has a blank), use `ROW_NUMBER() OVER (PARTITION BY flight_id ORDER BY loaded_at)` and keep row 1 instead.
5. **Cast types.** `read_files` with CSV may bring numbers and dates as strings unless types are inferred. Cast `flight_date`, `seat_capacity`, `passengers`, `avg_fare`, `ticket_revenue`, `delay_minutes` and the two departure columns explicitly in Silver.
6. **Percentages in Gold.** Always compute `load_factor_pct = SUM(passengers) * 100.0 / SUM(seat_capacity)` and `on_time_pct = On Time flights * 100.0 / COUNT(*)`. Use `100.0`, not `100`, to avoid integer division. Never average per-flight percentages, and never add or average percentages on the dashboard.
7. **Expectations are metrics too.** Dropped-row counts from `EXPECT ... ON VIOLATION DROP ROW` appear in the pipeline's data quality tab. Compare them to `rejected_rows` as an extra check.

---



## 8. Validation Queries

```sql
-- Duplicates remaining in Silver clean (expect 0)
SELECT flight_id, COUNT(*) FROM silver_flights_clean GROUP BY flight_id HAVING COUNT(*) > 1;

-- Blanks remaining in Silver clean (expect 0)
SELECT COUNT(*) FROM silver_flights_clean
WHERE airline IS NULL OR TRIM(airline) = ''
   OR delay_reason IS NULL OR TRIM(delay_reason) = ''
   OR delay_minutes IS NULL OR ticket_revenue IS NULL;

-- Impossible rows remaining in Silver clean (expect 0)
SELECT COUNT(*) FROM silver_flights_clean
WHERE passengers > seat_capacity OR passengers < 0 OR avg_fare < 0;

-- Category coverage (expect only 3 values, totals = 1,321)
SELECT delay_category, COUNT(*) FROM silver_flights_clean GROUP BY delay_category;

-- Reconciliation (expect true)
SELECT bronze_rows = clean_rows + rejected_rows + duplicate_rows AS reconciliation_passed
FROM gold_data_quality;
```
