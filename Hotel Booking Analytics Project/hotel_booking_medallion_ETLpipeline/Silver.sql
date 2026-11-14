-- 1. Silver Clean Table
CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_clean (
  CONSTRAINT valid_stay_dates EXPECT (check_out_date > check_in_date) ON VIOLATION DROP ROW,
  CONSTRAINT valid_room_rate EXPECT (room_rate >= 0) ON VIOLATION DROP ROW
) AS
SELECT DISTINCT
  booking_id,
  guest_id,
  CAST(booking_date AS DATE) AS booking_date,
  CAST(check_in_date AS DATE) AS check_in_date,
  CAST(check_out_date AS DATE) AS check_out_date,
  COALESCE(
    CAST(nights AS INT), 
    DATEDIFF(CAST(check_out_date AS DATE), CAST(check_in_date AS DATE))
  ) AS nights,
  TRIM(hotel_name) AS hotel_name,
  COALESCE(INITCAP(TRIM(city)), 'Unknown') AS city,
  INITCAP(TRIM(region)) AS region,
  INITCAP(TRIM(room_type)) AS room_type,
  COALESCE(INITCAP(TRIM(booking_channel)), 'Unknown') AS booking_channel,
  CAST(guests AS INT) AS guests,
  CAST(room_rate AS DECIMAL(10,2)) AS room_rate,
  COALESCE(
    CAST(total_amount AS DECIMAL(10,2)),
    DATEDIFF(CAST(check_out_date AS DATE), CAST(check_in_date AS DATE)) * CAST(room_rate AS DECIMAL(10,2))
  ) AS total_amount,
  COALESCE(CAST(discount_amount AS DECIMAL(10,2)), 0.00) AS discount_amount,
  INITCAP(TRIM(meal_plan)) AS meal_plan,
  TRIM(payment_method) AS payment_method,
  INITCAP(TRIM(payment_status)) AS payment_status,
  INITCAP(TRIM(booking_status)) AS booking_status,
  CAST(guest_rating AS DOUBLE) AS guest_rating
FROM bronze_hotel_bookings;

-- 2. Silver Rejected Table (Audit trail for dropped rows)
CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_rejected AS
SELECT 
  *,
  CASE 
    WHEN CAST(check_out_date AS DATE) <= CAST(check_in_date AS DATE) THEN 'Check-out is not after check-in'
    WHEN CAST(room_rate AS DECIMAL(10,2)) < 0 THEN 'Room rate is negative'
    ELSE 'Other data quality violation'
  END AS reject_reason
FROM bronze_hotel_bookings
WHERE CAST(check_out_date AS DATE) <= CAST(check_in_date AS DATE) 
   OR CAST(room_rate AS DECIMAL(10,2)) < 0;