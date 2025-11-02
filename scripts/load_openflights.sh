-- ============================================
-- LOAD OPENFLIGHTS DATASET
-- Airlines, Airports, and Routes
-- ============================================

USE flight_emissions;

-- Disable foreign key checks for loading
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- LOAD AIRLINES
-- ============================================

SELECT 'Loading airlines...' AS status;

LOAD DATA LOCAL INFILE 'data/openflights/airlines.dat'
INTO TABLE airlines
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(airline_id, name, @alias, @iata, @icao, @callsign, country, @active)
SET 
    alias = NULLIF(@alias, '\\N'),
    iata_code = NULLIF(@iata, '\\N'),
    icao_code = NULLIF(@icao, '\\N'),
    callsign = NULLIF(@callsign, '\\N'),
    active = NULLIF(@active, '\\N');

SELECT CONCAT('✅ Loaded ', COUNT(*), ' airlines') AS status FROM airlines;

-- ============================================
-- LOAD AIRPORTS
-- ============================================

SELECT 'Loading airports...' AS status;

LOAD DATA LOCAL INFILE 'data/openflights/airports.dat'
INTO TABLE airports
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(airport_id, name, city, country, @iata, @icao, 
 latitude, longitude, altitude, @tz_offset, @dst, @tz_db, @type, @source)
SET 
    iata_code = NULLIF(@iata, '\\N'),
    icao_code = NULLIF(@icao, '\\N'),
    timezone_offset = NULLIF(@tz_offset, '\\N'),
    dst = NULLIF(@dst, '\\N'),
    tz_database = NULLIF(@tz_db, '\\N'),
    type = NULLIF(@type, '\\N'),
    source = NULLIF(@source, '\\N');

SELECT CONCAT('✅ Loaded ', COUNT(*), ' airports') AS status FROM airports;

-- ============================================
-- LOAD ROUTES
-- ============================================

SELECT 'Loading routes...' AS status;

-- 🌟 COLUMNSTORE OPTIMIZATION: Use batch insert optimization
SET columnstore_use_import_for_batchinsert = ON;

-- Initialize a counter for the route_id and a timestamp for the batch
SET @route_id_counter = 0;
SET @load_timestamp = NOW();

LOAD DATA LOCAL INFILE 'data/openflights/routes_sorted.dat'
INTO TABLE routes
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(@airline, @airline_id, @src_airport, @src_id, 
 @dst_airport, @dst_id, @codeshare, @stops, @equipment)
SET 
    -- 1. Generate the route_id by incrementing the counter for each row
    route_id = (@route_id_counter := @route_id_counter + 1),
    created_at = @load_timestamp,
    airline_code = NULLIF(@airline, '\\N'),
    airline_id = NULLIF(@airline_id, '\\N'),
    source_airport = NULLIF(@src_airport, '\\N'),
    source_airport_id = NULLIF(@src_id, '\\N'),
    destination_airport = NULLIF(@dst_airport, '\\N'),
    destination_airport_id = NULLIF(@dst_id, '\\N'),
    codeshare = NULLIF(@codeshare, '\\N'),
    stops = NULLIF(@stops, '\\N'),
    equipment = NULLIF(@equipment, '\\N');

SELECT CONCAT('✅ Loaded ', COUNT(*), ' routes') AS status FROM routes;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- DATA QUALITY CHECKS
-- ============================================

SELECT '📊 Data Quality Report' AS report;
SELECT '========================' AS separator;

-- Check for routes with valid airports
SELECT 
    'Routes with valid airports' AS metric,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM routes), 1) AS percentage
FROM routes r
WHERE EXISTS (SELECT 1 FROM airports WHERE iata_code = r.source_airport)
  AND EXISTS (SELECT 1 FROM airports WHERE iata_code = r.destination_airport);

-- Check for routes with valid airlines
SELECT 
    'Routes with valid airlines' AS metric,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM routes), 1) AS percentage
FROM routes r
WHERE EXISTS (SELECT 1 FROM airlines WHERE iata_code = r.airline_code);

-- Check for duplicate routes
SELECT 
    'Duplicate routes' AS metric,
    COUNT(*) AS count
FROM (
    SELECT source_airport, destination_airport, airline_code, COUNT(*) as cnt
    FROM routes
    GROUP BY source_airport, destination_airport, airline_code
    HAVING cnt > 1
) AS duplicates;

-- Top 10 airlines by route count
SELECT 
    airline_code,
    al.name AS airline_name,
    COUNT(*) AS route_count
FROM routes r
LEFT JOIN airlines al ON r.airline_code = al.iata_code
GROUP BY airline_code, al.name
ORDER BY route_count DESC
LIMIT 10;

-- Top 10 airports by route count
SELECT 
    source_airport,
    ap.name AS airport_name,
    ap.city,
    COUNT(*) AS route_count
FROM routes r
LEFT JOIN airports ap ON r.source_airport = ap.iata_code
GROUP BY source_airport, ap.name, ap.city
ORDER BY route_count DESC
LIMIT 10;

-- Storage analysis
SELECT 
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
