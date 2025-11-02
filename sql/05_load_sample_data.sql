-- ============================================
-- FLIGHT RECORDS CSV DATA LOADER
-- Load flight data from CSV using cpimport
-- ============================================

USE flight_emissions;

-- ============================================
-- CSV IMPORT INSTRUCTIONS
-- ============================================
-- To load flight records data from CSV file:
--
-- METHOD 1: Use the provided shell script (recommended):
-- ./scripts/load_flight_data.sh
--
-- METHOD 2: Manual cpimport command (run from project root):
-- sudo cpimport -s ',' -E '"' flight_emissions flight_records $(pwd)/data/flight_records.csv
--
-- CSV file format expected:
-- route_id,flight_date,passengers,load_factor,cabin_class,aircraft_type,co2_per_passenger_kg,total_co2_kg
--
-- After loading data, continue to the VALIDATION section below.

SELECT '✈️  Flight Records CSV Data Loader' AS status;
SELECT 'Use ./scripts/load_flight_data.sh to load CSV data' AS instruction;

-- ============================================
-- DATA VALIDATION
-- ============================================

SELECT
    '✅ Data Load Validation' AS status,
    COUNT(*) AS total_flights,
    COUNT(DISTINCT route_id) AS unique_routes,
    MIN(flight_date) AS earliest_flight,
    MAX(flight_date) AS latest_flight,
    ROUND(AVG(passengers), 0) AS avg_passengers,
    ROUND(SUM(total_co2_kg) / 1000000, 2) AS total_co2_megatonnes
FROM flight_records;

-- Value ranges
SELECT
    'Value Ranges' AS check_type,
    ROUND(MIN(co2_per_passenger_kg), 2) AS min_co2_per_pax,
    ROUND(MAX(co2_per_passenger_kg), 2) AS max_co2_per_pax,
    ROUND(MIN(total_co2_kg), 2) AS min_total_co2,
    ROUND(MAX(total_co2_kg), 2) AS max_total_co2
FROM flight_records;

-- Cabin class distribution
SELECT
    cabin_class,
    COUNT(*) AS flights,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM flight_records), 1) AS pct,
    ROUND(MIN(co2_per_passenger_kg), 2) AS min_co2,
    ROUND(AVG(co2_per_passenger_kg), 2) AS avg_co2,
    ROUND(MAX(co2_per_passenger_kg), 2) AS max_co2
FROM flight_records
GROUP BY cabin_class
ORDER BY
    CASE cabin_class
        WHEN 'economy' THEN 1
        WHEN 'business' THEN 2
        ELSE 3
    END;

-- Monthly distribution
SELECT
    DATE_FORMAT(flight_date, '%Y-%m') AS month,
    COUNT(*) AS flights,
    ROUND(SUM(total_co2_kg) / 1000, 2) AS co2_tonnes,
    ROUND(AVG(passengers), 0) AS avg_pax
FROM flight_records
GROUP BY month
ORDER BY month;

-- Top routes by emissions
SELECT
    CONCAT(r.source_airport, ' → ', r.destination_airport) AS route,
    r.distance_km,
    COUNT(*) AS flights,
    ROUND(AVG(fr.passengers), 0) AS avg_pax,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS total_co2_tonnes
FROM flight_records fr
JOIN routes r ON fr.route_id = r.route_id
GROUP BY route, r.distance_km
ORDER BY total_co2_tonnes DESC
LIMIT 10;

-- Storage stats
SELECT
    'Storage Analysis' AS report,
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions'
  AND TABLE_NAME IN ('routes', 'flight_records')
ORDER BY TABLE_ROWS DESC;
