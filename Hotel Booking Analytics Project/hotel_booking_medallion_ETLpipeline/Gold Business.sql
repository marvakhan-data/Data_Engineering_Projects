-- BR-01: Monthly Booking & Revenue Trends
CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_bookings AS
SELECT 
  DATE_TRUNC('MONTH', check_in_date) AS stay_month,
  COUNT(*) AS bookings,
  SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
  SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
  SUM(CASE WHEN booking_status = 'Completed' THEN (total_amount - discount_amount) ELSE 0 END) AS net_revenue
FROM silver_bookings_clean
GROUP BY DATE_TRUNC('MONTH', check_in_date);

-- BR-02: Hotel Performance & Average Daily Rate (ADR)
CREATE OR REFRESH MATERIALIZED VIEW gold_hotel_summary AS
SELECT 
  region,
  city,
  hotel_name,
  COUNT(*) AS bookings,
  SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
  SUM(CASE WHEN booking_status = 'Completed' THEN (total_amount - discount_amount) ELSE 0 END) AS net_revenue,
  ROUND(
    SUM(CASE WHEN booking_status = 'Completed' THEN (total_amount - discount_amount) ELSE 0 END) / 
    NULLIF(SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END), 0), 
    2
  ) AS avg_daily_rate
FROM silver_bookings_clean
GROUP BY region, city, hotel_name;

-- BR-03: Room Type Performance & Guest Ratings
CREATE OR REFRESH MATERIALIZED VIEW gold_room_type_summary AS
SELECT 
  room_type,
  COUNT(*) AS bookings,
  SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
  SUM(CASE WHEN booking_status = 'Completed' THEN (total_amount - discount_amount) ELSE 0 END) AS net_revenue,
  ROUND(AVG(guest_rating), 2) AS avg_rating
FROM silver_bookings_clean
GROUP BY room_type;

-- BR-04: Booking Channel & Cancellation Analysis
CREATE OR REFRESH MATERIALIZED VIEW gold_channel_summary AS
SELECT 
  booking_channel,
  COUNT(*) AS bookings,
  SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
  ROUND(
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
    2
  ) AS cancellation_rate_pct,
  SUM(CASE WHEN booking_status = 'Completed' THEN (total_amount - discount_amount) ELSE 0 END) AS net_revenue
FROM silver_bookings_clean
GROUP BY booking_channel;