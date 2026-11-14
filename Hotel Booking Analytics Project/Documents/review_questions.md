# Project Review Questions and Answers

## 1. Why do we keep the raw data in Bronze instead of cleaning the file directly?
Bronze is the untouched source of truth. If a cleaning rule is wrong or changes later, we can re-run Silver and Gold from Bronze without re-uploading the file. It also gives lineage (`source_file`, `loaded_at`) and lets us count the original problems for the data-quality table.

## 2. Why is a cancelled booking kept, but a booking with check-out before check-in rejected?
A cancellation is a real business event, so it is valid data and is needed for cancellation-rate analysis. A check-out on or before check-in is impossible, so the data is wrong and would corrupt nights and revenue. It goes to the rejected table with a reason.

## 3. Why can booking_id find duplicates but guest_id cannot?
`booking_id` is unique per booking (one row = one booking), so a repeat means a copied row. One guest can legitimately make many bookings, so a repeated `guest_id` is normal.

## 4. How does DATEDIFF fill a blank nights value, and what happens if you swap its arguments?
`DATEDIFF(check_out_date, check_in_date)` returns the number of days from check-in to check-out, e.g. 3 for 20 Apr to 23 Apr. If the arguments are swapped, the result is negative (-3), which gives negative nights and negative revenue.

## 5. Why do we leave a blank rating as NULL instead of replacing it with 0?
Cancelled stays have no rating. `AVG()` ignores NULL, so the average reflects only real ratings. Replacing blanks with 0 would wrongly pull the average down.

## 6. What is the average daily rate (ADR), and why is it calculated as net revenue / room nights?
ADR is the average revenue earned per occupied room night. Dividing total net revenue by total room nights weights each stay by its length. Averaging per-booking rates would treat a 1-night and a 10-night stay equally and give a wrong result.

## 7. Which booking channel has the highest cancellation rate?


```sql
SELECT booking_channel, bookings, cancelled_bookings,
       ROUND(cancellation_rate_pct, 2) AS cancellation_rate_pct
FROM gold_channel_summary
ORDER BY cancellation_rate_pct DESC
LIMIT 1;
```

**Answer:** `Website` with `15.8%%` and `Mobile App` is nearly tied at `15.4%`


