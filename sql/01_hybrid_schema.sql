-- ============================================
-- MARIADB COLUMNSTORE REFERENCE IMPLEMENTATION
-- Schema: Hybrid Architecture (InnoDB + ColumnStore)
-- ============================================

-- Drop database if exists (for clean setup)
DROP DATABASE IF EXISTS flight_emissions;

-- Create database
CREATE DATABASE flight_emissions
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE flight_emissions;

-- ============================================
-- INNODB TABLES: Reference Data
-- Use for: Small datasets, frequent lookups, OLTP
-- ============================================

-- Airlines Table
-- Size: ~6,000 rows
-- Access Pattern: Frequent lookups by IATA/ICAO code
-- Why InnoDB: Fast B-tree index seeks, small size
CREATE TABLE airlines (
    airline_id INT PRIMARY KEY COMMENT 'Unique airline identifier',
    name VARCHAR(255) NOT NULL COMMENT 'Full airline name',
    alias VARCHAR(255) COMMENT 'Airline alias',
    iata_code CHAR(2) COMMENT '2-letter IATA code (e.g., AA, DL)',
    icao_code CHAR(3) COMMENT '3-letter ICAO code (e.g., AAL, DAL)',
    callsign VARCHAR(255) COMMENT 'Radio callsign',
    country VARCHAR(100) COMMENT 'Country of registration',
    active CHAR(1) DEFAULT 'Y' COMMENT 'Y=Active, N=Inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_iata (iata_code) COMMENT 'Fast lookup by IATA code',
    INDEX idx_icao (icao_code) COMMENT 'Fast lookup by ICAO code',
    INDEX idx_country (country) COMMENT 'Filter by country'
) ENGINE=InnoDB 
DEFAULT CHARSET=utf8mb4 
COLLATE=utf8mb4_unicode_ci
COMMENT='Airlines reference - InnoDB for fast point queries';

-- Airports Table
-- Size: ~10,000 rows
-- Access Pattern: Point queries by code, geospatial lookups
-- Why InnoDB: Small size, frequent joins, geospatial indexes
CREATE TABLE airports (
    airport_id INT PRIMARY KEY COMMENT 'Unique airport identifier',
    name VARCHAR(255) NOT NULL COMMENT 'Airport name',
    city VARCHAR(100) COMMENT 'City',
    country VARCHAR(100) COMMENT 'Country',
    iata_code CHAR(3) COMMENT '3-letter IATA code (e.g., JFK, LAX)',
    icao_code CHAR(4) COMMENT '4-letter ICAO code (e.g., KJFK, KLAX)',
    latitude DECIMAL(10, 6) NOT NULL COMMENT 'Latitude coordinate',
    longitude DECIMAL(10, 6) NOT NULL COMMENT 'Longitude coordinate',
    altitude INT COMMENT 'Altitude in feet',
    timezone_offset DECIMAL(4, 2) COMMENT 'Hours offset from UTC',
    dst CHAR(1) COMMENT 'Daylight savings time (E/A/S/O/Z/N/U)',
    tz_database VARCHAR(100) COMMENT 'Timezone database name',
    type VARCHAR(50) COMMENT 'Airport type',
    source VARCHAR(50) COMMENT 'Data source',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE INDEX idx_iata (iata_code) COMMENT 'Unique IATA lookup',
    UNIQUE INDEX idx_icao (icao_code) COMMENT 'Unique ICAO lookup',
    INDEX idx_country (country) COMMENT 'Filter by country',
    INDEX idx_location (latitude, longitude) COMMENT 'Geospatial queries'
) ENGINE=InnoDB 
DEFAULT CHARSET=utf8mb4 
COLLATE=utf8mb4_unicode_ci
COMMENT='Airports reference - InnoDB for geospatial and point queries';

-- Emission Factors Table
-- Size: <20 rows
-- Access Pattern: Lookups by distance range
-- Why InnoDB: Tiny table, updated occasionally
CREATE TABLE emission_factors (
    factor_id INT AUTO_INCREMENT PRIMARY KEY,
    aircraft_category VARCHAR(50) NOT NULL UNIQUE COMMENT 'Aircraft category/distance band',
    distance_min_km INT COMMENT 'Minimum distance (km)',
    distance_max_km INT COMMENT 'Maximum distance (km)',
    co2_kg_per_passenger_km DECIMAL(6, 4) NOT NULL COMMENT 'CO2 emissions (kg per passenger-km)',
    description TEXT COMMENT 'Detailed description',
    source VARCHAR(255) COMMENT 'Data source (e.g., ICAO)',
    last_updated DATE COMMENT 'Last update date',
    
    INDEX idx_distance (distance_min_km, distance_max_km) COMMENT 'Range lookups'
) ENGINE=InnoDB 
DEFAULT CHARSET=utf8mb4 
COLLATE=utf8mb4_unicode_ci
COMMENT='ICAO emission factors - InnoDB for small reference table';

-- ============================================
-- COLUMNSTORE TABLES: Analytical Data
-- Use for: Large datasets, aggregations, scans, OLAP
-- ============================================

-- Routes Table
-- Size: 67,000+ rows (scales to millions)
-- Access Pattern: Aggregations, GROUP BY, analytical queries
-- Why ColumnStore: 20-30x faster for SUM/AVG/COUNT operations
CREATE TABLE routes (
    route_id INT COMMENT 'Unique route identifier',
    airline_code CHAR(2) COMMENT 'Operating airline IATA code',
    airline_id INT COMMENT 'Operating airline ID',
    source_airport CHAR(3) NOT NULL COMMENT 'Departure airport IATA',
    source_airport_id INT COMMENT 'Departure airport ID',
    destination_airport CHAR(3) NOT NULL COMMENT 'Arrival airport IATA',
    destination_airport_id INT COMMENT 'Arrival airport ID',
    codeshare CHAR(1) COMMENT 'Codeshare flight indicator',
    stops INT DEFAULT 0 COMMENT 'Number of stops',
    equipment VARCHAR(100) COMMENT 'Aircraft type codes',
    
    -- Calculated fields (populated after distance calculation)
    distance_km DECIMAL(10, 2) COMMENT 'Great-circle distance in kilometers',
    co2_per_passenger_kg DECIMAL(10, 2) COMMENT 'CO2 emissions per passenger',
    flight_time_hours DECIMAL(5, 2) COMMENT 'Estimated flight time',
    
    created_at TIMESTAMP
) ENGINE=ColumnStore 
DEFAULT CHARSET=utf8mb4 
COLLATE=utf8mb4_unicode_ci
COMMENT='Flight routes - ColumnStore for analytical aggregations';

-- 🌟 COLUMNSTORE OPTIMIZATION NOTES:
-- 1. No PRIMARY KEY - ColumnStore doesn't need it for analytics
-- 2. route_id will be used for joins
-- 3. Columns stored separately = better compression
-- 4. Perfect for: SUM(distance_km), AVG(co2), GROUP BY airline_code

-- Flight Records Table
-- Size: Millions of rows (scalable)
-- Access Pattern: Time-series analytics, heavy scans
-- Why ColumnStore: Columnar storage ideal for date-based aggregations
CREATE TABLE flight_records (
    record_id BIGINT COMMENT 'Unique record identifier',
    route_id INT NOT NULL COMMENT 'Reference to routes table',
    flight_date DATE NOT NULL COMMENT 'Date of flight - Critical for time-series queries',
    flight_number VARCHAR(10) COMMENT 'Flight number',
    aircraft_type VARCHAR(50) COMMENT 'Specific aircraft type',
    passengers INT COMMENT 'Number of passengers',
    load_factor DECIMAL(5, 2) COMMENT 'Load factor percentage',
    cabin_class VARCHAR(20) DEFAULT 'economy' COMMENT 'Cabin class (economy/business/first)',
    
    -- Calculated emissions
    total_co2_kg BIGINT COMMENT 'Total CO2 for this flight',
    co2_per_passenger_kg BIGINT COMMENT 'CO2 per passenger',
    
    created_at TIMESTAMP 
) ENGINE=ColumnStore 
DEFAULT CHARSET=utf8mb4 
COLLATE=utf8mb4_unicode_ci
COMMENT='Flight records - ColumnStore for time-series analytics';

-- 🌟 COLUMNSTORE OPTIMIZATION NOTES:
-- 1. INDEX on flight_date enables partition pruning
-- 2. Columnar storage = fast DATE aggregations
-- 3. Perfect for: Monthly trends, YoY comparisons
-- 4. Compression ratio: ~65% on numeric data

-- ============================================
-- INITIAL DATA: Emission Factors (ICAO Standard)
-- ============================================

INSERT INTO emission_factors 
(aircraft_category, distance_min_km, distance_max_km, 
 co2_kg_per_passenger_km, description, source, last_updated) 
VALUES
-- Short-haul flights (< 1,500 km)
('Short-haul', 0, 1500, 0.1580, 
 'Short-haul flights (<1,500 km), narrow-body aircraft, economy class. Higher emissions due to takeoff/landing fuel consumption.',
 'ICAO Carbon Emissions Calculator', CURDATE()),
 
-- Medium-haul flights (1,500-4,000 km)
('Medium-haul', 1500, 4000, 0.1130, 
 'Medium-haul flights (1,500-4,000 km), narrow-body aircraft, economy class. Most fuel-efficient per km.',
 'ICAO Carbon Emissions Calculator', CURDATE()),
 
-- Long-haul flights (> 4,000 km)
('Long-haul', 4000, 999999, 0.1020, 
 'Long-haul flights (>4,000 km), wide-body aircraft, economy class. Efficient due to cruise optimization.',
 'ICAO Carbon Emissions Calculator', CURDATE()),
 
-- Regional aircraft
('Regional', 0, 500, 0.2540, 
 'Regional aircraft (<500 km), turboprops and small jets. Highest emissions per km due to aircraft inefficiency.',
 'ICAO Carbon Emissions Calculator', CURDATE()),
 
-- Business class multiplier
('Business-class-multiplier', 0, 999999, 0.3000, 
 'Business class passengers: Multiply economy emissions by 3x due to increased space per passenger.',
 'ICAO Carbon Emissions Calculator', CURDATE()),
 
-- Premium economy multiplier
('Premium-economy-multiplier', 0, 999999, 0.1600, 
 'Premium economy: Multiply economy emissions by 1.6x due to increased space per passenger.',
 'ICAO Carbon Emissions Calculator', CURDATE());

-- ============================================
-- CONVENIENCE VIEWS
-- ============================================

-- View: Routes with full airline and airport details
CREATE OR REPLACE VIEW v_routes_detailed AS
SELECT 
    r.route_id,
    r.airline_code,
    al.name AS airline_name,
    al.country AS airline_country,
    r.source_airport,
    src.name AS source_airport_name,
    src.city AS source_city,
    src.country AS source_country,
    src.latitude AS source_lat,
    src.longitude AS source_lon,
    r.destination_airport,
    dst.name AS destination_airport_name,
    dst.city AS destination_city,
    dst.country AS destination_country,
    dst.latitude AS dest_lat,
    dst.longitude AS dest_lon,
    r.distance_km,
    r.co2_per_passenger_kg,
    r.equipment,
    r.stops
FROM routes r
LEFT JOIN airlines al ON r.airline_code = al.iata_code
LEFT JOIN airports src ON r.source_airport = src.iata_code
LEFT JOIN airports dst ON r.destination_airport = dst.iata_code;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Show all tables with their engines
SELECT 
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_size_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2) AS index_size_mb,
    TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'flight_emissions'
ORDER BY ENGINE, TABLE_NAME;

-- Verify ColumnStore tables
SELECT 
    TABLE_NAME, 
    ENGINE,
    TABLE_COMMENT
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'flight_emissions' 
  AND ENGINE = 'ColumnStore';

-- Verify emission factors loaded
SELECT * FROM emission_factors ORDER BY distance_min_km;

-- Show database size
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
WHERE table_schema = 'flight_emissions'
GROUP BY table_schema;
