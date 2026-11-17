# Reconciliation

## Overview

In this project, I used reconciliation to check whether all the records loaded into the Bronze layer were properly accounted for after data cleaning.

The main purpose was to make sure that no records were missing during the movement from Bronze to Silver.

## Reconciliation Formula

I used the following formula:

`Bronze Rows = Clean Rows + Rejected Rows + Duplicate Rows Removed`

Every row from the original data should be accounted for in one of these categories:

- Clean records that passed the data quality rules.
- Rejected records that failed the validation rules.
- Duplicate records removed during cleaning.

## Row Count Validation

The original airline dataset contains 1,365 rows.

| Layer or Category | What I Checked |
|---|---|
| Bronze | Total records loaded from the CSV |
| Silver Clean | Records that passed the cleaning rules |
| Silver Rejected | Records that failed validation |
| Duplicates Removed | Extra records with repeated flight_id values |

The project reference expects:

- Bronze rows: 1,365
- Clean Silver rows: 1,321

I use the actual pipeline output to verify the rejected and duplicate counts.

## Why I Used flight_id

I used `flight_id` to identify duplicate records because it represents one flight on a particular day.

I did not use `flight_number` because the same flight number can operate on different days. Using it for duplicate checking could remove valid records.

## Reconciliation in Gold Layer

I created a Gold table named `gold_data_quality` to track the row counts and data quality results.

It includes:

- Total Bronze rows
- Duplicate rows
- Clean Silver rows
- Rejected Silver rows
- Other data quality issue counts

I use these values to verify that the records are properly accounted for after cleaning.

## What I Check If Reconciliation Does Not Match

If the Bronze total does not match the sum of clean, rejected and duplicate rows, I investigate the issue.

I check:

1. Whether duplicate records were counted correctly.
2. Whether rejected records were included in the rejected table.
3. Whether any records were missed during cleaning.
4. Whether the row counts belong to the same pipeline run.

After checking the issue, I validate the counts again.

## Final Validation

Before using the Gold tables for reporting, I check that:

- Bronze contains the expected source records.
- Duplicate records are identified using `flight_id`.
- Valid records are stored in `silver_flights_clean`.
- Invalid records are stored in `silver_flights_rejected` with a rejection reason.
- The reconciliation formula matches the actual pipeline counts.
- Gold summary tables and dashboard totals agree with the clean Silver data.

## Conclusion

Reconciliation helped me verify that all records from the original CSV were accounted for after data cleaning. It also helped me make sure that valid and rejected records were handled separately.

This gives me more confidence in the Gold tables and the business results displayed in the dashboard.