# Data Quality Rules

Source: `hotel_bookings_raw.csv` (1,316 rows, 20 columns, synthetic data).

Rule of thumb: **Bronze keeps everything, Silver fixes or rejects, Gold only reads clean data.**

## A. Rules that FIX the data (row is kept)

| ID | Problem | Column(s) | Rule | SQL |
|----|---------|-----------|------|-----|
| DQ-01 | Extra spaces / mixed case | city, room_type, booking_channel, meal_plan | Trim spaces, convert to Title Case | `INITCAP(TRIM(col))` |
| DQ-02 | Blank city | city | Replace with `Unknown` | `COALESCE(NULLIF(INITCAP(TRIM(city)),''), 'Unknown')` |
| DQ-03 | Blank booking channel | booking_channel | Replace with `Unknown` | `COALESCE(NULLIF(INITCAP(TRIM(booking_channel)),''), 'Unknown')` |
| DQ-04 | Blank nights | nights | Calculate from dates | `COALESCE(nights, DATEDIFF(check_out_date, check_in_date))` |
| DQ-05 | Blank total amount | total_amount | Calculate nights x room_rate | `COALESCE(total_amount, DATEDIFF(check_out_date, check_in_date) * room_rate)` |
| DQ-06 | Blank discount | discount_amount | Treat as 0 so net revenue is not NULL | `COALESCE(discount_amount, 0)` |
| DQ-07 | Blank guest_id | guest_id | Keep as NULL (cannot be recovered) | No change |
| DQ-08 | Blank guest_rating | guest_rating | Keep as NULL (AVG ignores NULL; 0 would lower the average) | No change |

## B. Rules that REMOVE the data (row goes to the rejected table with a reason)

| ID | Problem | Rule | Reject reason |
|----|---------|------|---------------|
| DQ-09 | Check-out on or before check-in | `check_out_date <= check_in_date` | Check-out is not after check-in |
| DQ-10 | Negative room rate | `room_rate < 0` | Room rate is negative |

## C. Rules that DEDUPLICATE

| ID | Problem | Rule |
|----|---------|------|
| DQ-11 | Same `booking_id` appears more than once | Keep one copy per `booking_id`; count the extra copies as `duplicate_rows` |

## D. Business rules (Gold layer)

| ID | Rule |
|----|------|
| BR-A | Cancelled bookings are NOT bad data. Keep them in Silver. |
| BR-B | `net_revenue = total_amount - discount_amount` for `booking_status = 'Completed'` only. |
| BR-C | `room_nights = SUM(nights)` for `booking_status = 'Completed'` only. |
| BR-D | `avg_daily_rate = net_revenue / room_nights` (never average the daily rates). |
| BR-E | `cancellation_rate_pct = cancelled_bookings * 100.0 / bookings`. |
| BR-F | Rates and ratings are not summed or averaged in the dashboard; show them per group. |

## E. Pipeline expectations (Silver)

| Constraint | Expectation | Action |
|-----------|-------------|--------|
| booking_id_present | `booking_id IS NOT NULL` | DROP ROW |
| valid_stay_dates | `check_out_date > check_in_date` | DROP ROW |
| valid_room_rate | `room_rate >= 0` | DROP ROW |

