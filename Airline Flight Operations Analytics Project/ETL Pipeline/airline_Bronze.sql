
CREATE OR REFRESH STREAMING TABLE bronze_airline_flights AS

SELECT
    *,
    _metadata.file_name AS source_file,
    current_timestamp() AS loaded_at

FROM STREAM read_files(
    '/Volumes/aviation_catalog/flights/raw_files',
    format => 'csv',
    header => true
);
