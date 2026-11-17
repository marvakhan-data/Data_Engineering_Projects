<div align="center">

# Project Review Questions and Answers

**Airline Flight Operations Analytics Platform**

![Questions](https://img.shields.io/badge/Questions-8-blue?style=flat-square)
![Topics](https://img.shields.io/badge/Topics-Medallion%20%7C%20SQL%20%7C%20Data%20Quality%20%7C%20BI-orange?style=flat-square)

</div>

[← Back to README](../README.md) · [Data Quality Rules](data_quality_rules.md) · [Reconciliation](reconciliation.md)

These are the eight review questions from the project brief, with answers written the way I would explain them in an interview or project presentation.

---

## Quick Index

| # | Question | Topic |
|---|---|---|
| 1 | [Why keep raw data in Bronze?](#q1-why-do-we-keep-the-raw-data-in-bronze-instead-of-cleaning-the-file-directly) | Medallion design |
| 2 | [Negative delay accepted, overbooked rejected?](#q2-why-is-a-negative-delay-accepted-but-a-flight-with-more-passengers-than-seats-rejected) | Data quality rules |
| 3 | [`flight_id` vs `flight_number`](#q3-why-can-flight_id-find-duplicates-but-flight_number-cannot) | Grain and keys |
| 4 | [How `TIMESTAMPDIFF` works](#q4-how-does-timestampdiff-fill-a-blank-delay-and-what-happens-if-you-swap-the-two-timestamps) | SQL functions |
| 5 | [Load factor calculation](#q5-why-do-we-calculate-load-factor-as-sumpassengers--sumseats-instead-of-averaging-each-flights-load-factor) | KPI design |
| 6 | [`100.0` vs `100`](#q6-why-do-we-multiply-by-1000-and-not-100-when-calculating-percentages) | SQL numerics |
| 7 | [Best on-time airline and top delay reason](#q7-which-airline-has-the-best-on-time-performance-and-what-is-the-most-common-delay-reason) | Analysis |
| 8 | [Dashboard tool choice](#q8-which-dashboard-tool-did-you-choose-and-why) | BI |

---

## Q1. Why do we keep the raw data in Bronze instead of cleaning the file directly?

**Short answer:** Bronze is the untouched record of what was received, so we can always trace, audit and reprocess.

- **Traceability:** we can prove what the source system actually sent, including `source_file` and `loaded_at`.
- **Reprocessing:** if a cleaning rule is wrong or changes, we re-run Silver from Bronze. We do not need to ask for the file again.
- **Reconciliation:** the check `bronze_rows = clean + rejected + duplicates` is only possible because Bronze keeps every original row, including the bad ones.
- **Debugging:** when a number looks wrong, we compare Gold back to Silver and Bronze to find where it changed.
- **Safety:** editing the source file directly destroys evidence. Cleaning is done in new tables, so the raw file is never modified.

---

## Q2. Why is a negative delay accepted, but a flight with more passengers than seats rejected?

**Short answer:** A negative delay is real and meaningful. More passengers than seats is physically impossible.

| | Negative `delay_minutes` | `passengers > seat_capacity` |
|---|---|---|
| Meaning | Flight **left early** | Impossible: cannot carry 215 people on 180 seats |
| Is it a true event? | Yes | No, it is a data error |
| Treatment | Keep, category **On Time** | Reject with reason |
| Effect if mishandled | Early flights wrongly removed, on-time % understated | Load factor can exceed 100%, revenue inflated |

The rule is: **reject data that cannot be true, keep data that is unusual but valid.** The same logic applies to negative `avg_fare`, which is not a real ticket price.

---

## Q3. Why can `flight_id` find duplicates but `flight_number` cannot?

**Short answer:** `flight_id` identifies one flight on one day. `flight_number` repeats on many days.

- Grain of the table is **one row = one flight on one day**, and `flight_id` is unique for each real flight.
- `SJ-472` may operate every day of the year, so it legitimately appears 300+ times with different dates. Those are not duplicates.
- If the **same `flight_id`** appears twice, it is the same flight recorded twice, so the extra copy is a duplicate.

```sql
-- Correct: duplicates by flight_id
SELECT flight_id, COUNT(*) FROM bronze_airline_flights GROUP BY flight_id HAVING COUNT(*) > 1;

-- Wrong: this would flag nearly every flight
SELECT flight_number, COUNT(*) FROM bronze_airline_flights GROUP BY flight_number HAVING COUNT(*) > 1;
```

---

## Q4. How does `TIMESTAMPDIFF` fill a blank delay, and what happens if you swap the two timestamps?

**How it works:** `TIMESTAMPDIFF(MINUTE, start, end)` returns the number of minutes from `start` to `end`.

```sql
COALESCE(delay_minutes,
         TIMESTAMPDIFF(MINUTE, scheduled_departure, actual_departure))
```

`COALESCE` uses the stored `delay_minutes` when present, and calculates it from the two departure times only when it is blank.

**Example:** scheduled 08:30, actual 09:12 gives **42** minutes late.

**If swapped:** `TIMESTAMPDIFF(MINUTE, actual_departure, scheduled_departure)` returns **−42**. The sign flips, so:

- Late flights look like early flights.
- They fall into the **On Time** category.
- On-time % is overstated and delays are understated.

Always put the **earlier planned time first** (scheduled), then the actual time.

---

## Q5. Why do we calculate load factor as `SUM(passengers) ÷ SUM(seats)` instead of averaging each flight's load factor?

**Short answer:** Averaging percentages gives every flight the same weight, even when planes are different sizes. A ratio of sums weights each flight by its seats.

**Example**

| Flight | Seats | Passengers | Load factor |
|---|---:|---:|---:|
| A (large plane) | 180 | 90 | 50% |
| B (small plane) | 60 | 60 | 100% |

- Average of the two percentages: (50 + 100) ÷ 2 = **75%** (misleading)
- Ratio of sums: (90 + 60) ÷ (180 + 60) = 150 ÷ 240 = **62.5%** (true share of seats filled)

The same principle applies to on-time %, which is `On Time flights ÷ all flights`, and it is why the dashboard must **never add or average percentage columns**. Calculate them from sums at each grouping level.

---

## Q6. Why do we multiply by `100.0` and not `100` when calculating percentages?

**Short answer:** `100.0` forces decimal arithmetic, so the result is never truncated to a whole number.

```sql
ROUND(SUM(passengers) * 100.0 / SUM(seat_capacity), 1) AS load_factor_pct
```

- In many SQL engines (for example SQL Server and PostgreSQL), integer ÷ integer gives an **integer**, so 151 × 100 ÷ 180 would become **83** instead of **83.9**.
- Using `100.0` makes the whole expression decimal, so the answer keeps its fractions before `ROUND`.
- In Databricks / Spark SQL, the `/` operator already returns a decimal result for integer inputs, so you would usually get the right value either way. `100.0` is still the safer habit: it makes the intent explicit and the query behaves the same if it is ever moved to another engine.

---

## Q7. Which airline has the best on-time performance, and what is the most common delay reason?

![Pic](/images/ontime.png)

![Pic](/images/delayed_flight.png)

**Best On-Time Performance:** Fly Easy leads all airlines with 71.5% on-time performance (followed by Air Bharat at 69.9%, Coastal Air at 69.3%, Blue Wing at 67.4%, and Sky Jet at 65.7%).

**Most Common Delay Reason:** Weather is the #1 delay reason with 108 delayed flights (out of 419 total delayed flights across all reasons, closely followed by Air Traffic with 104, Technical with 88, Late Arrival with 73, Crew with 43, and Unknown with 3).

## Q8. Which dashboard tool did you choose, and why?





 I chose Databricks AI/BI because it runs on the same SQL warehouse and Unity Catalog as the pipeline, so there is no extra connector, no data copy and permissions stay in one place. Datasets are simply the Gold tables, publishing is one click, and it can refresh on a schedule right after the pipeline runs.



