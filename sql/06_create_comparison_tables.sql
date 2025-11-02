-- ============================================
-- CREATE INNODB TABLES FOR PERFORMANCE COMPARISON
-- Side-by-side benchmarking: InnoDB vs ColumnStore
-- ============================================

USE flight_emissions;

SELECT '🔄 Creating InnoDB comparison tables...' AS status;

-- ============================================
-- CREATE IDENTICAL INNODB TABLES
-- ============================================

-- Drop if exists
DROP TABLE IF EXISTS routes_innodb;
DROP TABLE IF EXISTS flight_records_innodb;

-- Routes table (InnoDB version)
CREATE TABLE routes_innodb LIKE routes;

-- Change engine to InnoDB
ALTER TABLE routes_innodb ENGINE=InnoDB;

-- Add proper indexes for InnoDB optimization
ALTER TABLE routes_innodb 
    ADD PRIMARY KEY (route_id),
    ADD INDEX idx_airline (airline_code),
    ADD INDEX idx_source (source_airport),
    ADD INDEX idx_destination (destination_airport),
    ADD INDEX idx_distance (distance_km),
    ADD INDEX idx_co2 (co2_per_passenger_kg);

-- Flight records table (InnoDB version)
CREATE TABLE flight_records_innodb LIKE flight_records;

-- Change engine to InnoDB
ALTER TABLE flight_records_innodb ENGINE=InnoDB;

-- Add proper indexes for InnoDB optimization
ALTER TABLE flight_records_innodb 
    ADD PRIMARY KEY (record_id),
    ADD INDEX idx_route (route_id),
    ADD INDEX idx_date (flight_date),
    ADD INDEX idx_route_date (route_id, flight_date),
    ADD INDEX idx_co2 (total_co2_kg);

SELECT '✅ InnoDB tables created' AS status;

-- ============================================
-- COPY DATA FROM COLUMNSTORE TO INNODB
-- ============================================

SELECT '📥 Copying data to InnoDB tables...' AS status;

-- Copy routes
INSERT INTO routes_innodb 
SELECT * FROM routes;

SELECT CONCAT('✅ Copied ', COUNT(*), ' routes to InnoDB') AS status 
FROM routes_innodb;

-- Copy flight records (this may take a few minutes)
INSERT INTO flight_records_innodb 
SELECT * FROM flight_records;

SELECT CONCAT('✅ Copied ', COUNT(*), ' flight records to InnoDB') AS status 
FROM flight_records_innodb;

-- ============================================
-- STORAGE COMPARISON
-- ============================================

SELECT '📊 Storage Comparison: InnoDB vs ColumnStore' AS report;
SELECT '================================================' AS `separator`;

-- Compare storage for routes table
SELECT 
    'routes' AS table_name,
    'ColumnStore' AS engine,
    TABLE_ROWS AS `rows`,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME = 'routes'

UNION ALL

SELECT 
    'routes' AS table_name,
    'InnoDB' AS engine,
    TABLE_ROWS AS `rows`,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME = 'routes_innodb'

UNION ALL

SELECT 
    'flight_records' AS table_name,
    'ColumnStore' AS engine,
    TABLE_ROWS AS `rows`,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME = 'flight_records'

UNION ALL

SELECT 
    'flight_records' AS table_name,
    'InnoDB' AS engine,
    TABLE_ROWS AS `rows`,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME = 'flight_records_innodb';

-- Calculate compression savings
SELECT 
    '📦 Compression Analysis' AS metric,
    ROUND((
        (SELECT SUM(DATA_LENGTH + INDEX_LENGTH) FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME IN ('routes_innodb', 'flight_records_innodb')) -
        (SELECT SUM(DATA_LENGTH + INDEX_LENGTH) FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME IN ('routes', 'flight_records'))
    ) / 1024 / 1024, 2) AS space_saved_mb,
    ROUND((1 - (
        (SELECT SUM(DATA_LENGTH + INDEX_LENGTH) FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME IN ('routes', 'flight_records')) /
        (SELECT SUM(DATA_LENGTH + INDEX_LENGTH) FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA = 'flight_emissions' AND TABLE_NAME IN ('routes_innodb', 'flight_records_innodb'))
    )) * 100, 1) AS compression_percentage;

-- 🎯 COPY-PASTE TIP: Expect 60-70% compression with ColumnStore
-- Columnar storage compresses numeric/date columns very efficiently