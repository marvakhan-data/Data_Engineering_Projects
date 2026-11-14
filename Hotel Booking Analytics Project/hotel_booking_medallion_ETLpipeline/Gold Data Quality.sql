CREATE OR REFRESH MATERIALIZED VIEW gold_data_quality AS
SELECT 
  COUNT(*) AS bronze_rows,
  COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_rows,
  SUM(CASE WHEN CAST(check_out_date AS DATE) <= CAST(check_in_date AS DATE) THEN 1 ELSE 0 END) AS invalid_date_rows,
  SUM(CASE WHEN CAST(room_rate AS DECIMAL(10,2)) < 0 THEN 1 ELSE 0 END) AS negative_rate_rows,
  SUM(CASE WHEN city IS NULL OR TRIM(city) = '' THEN 1 ELSE 0 END) AS missing_city_rows,
  SUM(CASE WHEN booking_channel IS NULL OR TRIM(booking_channel) = '' THEN 1 ELSE 0 END) AS missing_channel_rows,
  SUM(CASE WHEN nights IS NULL OR TRIM(nights) = '' THEN 1 ELSE 0 END) AS missing_nights_rows,
  SUM(CASE WHEN total_amount IS NULL OR TRIM(total_amount) = '' THEN 1 ELSE 0 END) AS missing_amount_rows,
  (SELECT COUNT(*) FROM silver_bookings_clean) AS clean_rows,
  (SELECT COUNT(*) FROM silver_bookings_rejected) AS rejected_rows,
  CASE 
    WHEN COUNT(*) = (
      (SELECT COUNT(*) FROM silver_bookings_clean) + 
      (SELECT COUNT(*) FROM silver_bookings_rejected) + 
      (COUNT(*) - COUNT(DISTINCT booking_id))
    ) THEN 'Yes' 
    ELSE 'No' 
  END AS reconciliation_passed
FROM bronze_hotel_bookings;