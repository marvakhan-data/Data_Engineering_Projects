# Data Quality

## Overview

For this project, I added data quality checks to make sure the airline
flight data is clean and reliable before using it for business analysis.

The original CSV contains 1,365 rows. It includes common data issues
such as duplicate flights, extra spaces, inconsistent text formats,
missing values, passengers exceeding seat capacity and negative average
fares.

I used the Bronze, Silver and Gold layers to identify, clean and track
these issues.

## Data Quality Checks

I checked the following issues in the source data:

  -----------------------------------------------------------------------
  Check                   What I looked for       How I handled it
  ----------------------- ----------------------- -----------------------
  Duplicate flights       Repeated `flight_id`    Kept one copy of each
                          values                  flight

  Missing airline         Blank or null airline   Replaced missing values
                          values                  with `Unknown`

  Inconsistent text       Extra spaces and mixed  Used trimming and
                          capital letters in      consistent text
                          airline, city and delay formatting
                          reason fields           

  Missing delay minutes   Blank delay values      Calculated the delay
                                                  using scheduled and
                                                  actual departure times

  Missing ticket revenue  Blank revenue values    Calculated revenue
                                                  using passengers
                                                  multiplied by average
                                                  fare

  Passengers above seat   Passenger count greater Moved invalid records
  capacity                than available seats    to the rejected table

  Negative average fare   Average fare below zero Moved invalid records
                                                  to the rejected table

  Missing aircraft ID     Blank aircraft          Kept the record because
                          registration            the flight can still be
                                                  used for the other
                                                  analysis
  -----------------------------------------------------------------------

## Data Cleaning Rules

I applied these rules while preparing the Silver layer:

1.  I used `flight_id` to identify duplicate records because it
    represents one flight on one day. I did not use `flight_number` for
    duplicate checking because the same flight number can operate on
    different days.
2.  I removed extra spaces and standardised text values in fields such
    as airline, origin city, destination city and delay reason.
3.  I replaced a missing airline value with `Unknown`.
4.  When `delay_minutes` was missing, I calculated it using the
    difference between `scheduled_departure` and `actual_departure`.
5.  When `ticket_revenue` was missing, I calculated it as
    `passengers * avg_fare`.
6.  I rejected records where passengers were greater than seat capacity,
    where passenger count was negative, or where average fare was
    negative.
7.  I kept records with negative delay minutes because they represent
    flights that departed early.

Rejected records are stored separately in `silver_flights_rejected`,
along with a reason for rejection. Valid records are stored in
`silver_flights_clean`.

## Delay Classification

I created a `delay_category` column to make delay analysis easier:

  Delay minutes                                    Category
  ------------------------------------------------ -------------
  15 minutes or less, including early departures   On Time
  16 to 60 minutes                                 Minor Delay
  More than 60 minutes                             Major Delay

This classification is used in the Gold layer and dashboard.

## Reconciliation

After cleaning the data, I checked whether all Bronze records were
accounted for.

**Reconciliation formula:**

`Bronze Rows = Clean Rows + Rejected Rows + Duplicate Rows Removed`

The project reference expects:

-   Bronze rows: 1,365
-   Clean Silver rows: 1,321

I use the actual pipeline output to verify the rejected and duplicate
counts. If the reconciliation does not match, I investigate the records
before using the Gold tables for reporting.

## Gold Data Quality Summary

I created a Gold table named `gold_data_quality` to track the data
quality results. It includes checks such as:

-   Total Bronze rows
-   Duplicate rows
-   Overbooked flights
-   Missing airline values
-   Negative average fares
-   Missing delay values
-   Missing ticket revenue
-   Missing delay reasons
-   Clean Silver rows
-   Rejected Silver rows

This table helps me understand the quality of the source data and check
whether the cleaning process is working as expected.

## Final Validation

Before using the dashboard, I verify that:

-   Duplicate flights have been handled.
-   The required text fields and missing values have been cleaned.
-   Invalid passenger counts and negative fares are rejected.
-   Early departures are correctly classified as On Time.
-   Every source row is accounted for in the reconciliation.
-   The Gold summary numbers match the clean Silver data.
-   The delay categories add up to the total number of clean flights.

## Conclusion

These checks helped me turn the original airline CSV into more reliable
data for analysis. I kept the rejected records separately instead of
losing track of them, and used reconciliation to verify that the data
was accounted for across the pipeline.
