-- ============================================
-- HAVERSINE DISTANCE CALCULATION
-- Pure SQL implementation for geospatial distance
-- ============================================

USE flight_emissions;

-- Drop function if exists
DROP FUNCTION IF EXISTS haversine_distance;

-- Create Haversine distance function
DELIMITER $$

CREATE FUNCTION haversine_distance(
    lat1 DECIMAL(10,6),  -- Starting point latitude
    lon1 DECIMAL(10,6),  -- Starting point longitude
    lat2 DECIMAL(10,6),  -- Ending point latitude
    lon2 DECIMAL(10,6)   -- Ending point longitude
) RETURNS DECIMAL(10,2)
DETERMINISTIC
COMMENT 'Calculate great-circle distance in kilometers between two lat/lon coordinates'
BEGIN
    -- Earth's mean radius in kilometers
    DECLARE earth_radius DECIMAL(10,2) DEFAULT 6371.0;
    
    -- Difference in coordinates (in radians)
    DECLARE dlat DECIMAL(10,6);
    DECLARE dlon DECIMAL(10,6);
    
    -- Haversine formula variables
    DECLARE a DECIMAL(20,10);
    DECLARE c DECIMAL(20,10);
    DECLARE distance DECIMAL(10,2);
    
    -- Calculate differences
    SET dlat = RADIANS(lat2 - lat1);
    SET dlon = RADIANS(lon2 - lon1);
    
    -- Haversine formula
    -- a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
    SET a = POW(SIN(dlat / 2), 2) + 
            COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * 
            POW(SIN(dlon / 2), 2);
    
    -- c = 2 * atan2(√a, √(1-a))
    SET c = 2 * ATAN2(SQRT(a), SQRT(1 - a));
    
    -- distance = radius * c
    SET distance = earth_radius * c;
    
    RETURN distance;
END$$

DELIMITER ;

-- 🎯 COPY-PASTE TIP: This function works for ANY lat/lon pairs
-- Use for: Delivery routes, store locators, proximity search, distance-based fees

-- ============================================
-- TEST THE FUNCTION
-- ============================================

-- Test 1: New York (JFK) to London (LHR)
-- Expected: ~5,570 km
SELECT haversine_distance(
    40.6413, -73.7781,  -- JFK coordinates
    51.4700, -0.4543    -- LHR coordinates
) AS nyc_to_london_km;

-- Test 2: Los Angeles (LAX) to Tokyo (NRT)
-- Expected: ~8,800 km
SELECT haversine_distance(
    33.9416, -118.4085,  -- LAX coordinates
    35.7647, 140.3864    -- NRT coordinates
) AS lax_to_tokyo_km;

-- Test 3: San Francisco (SFO) to Singapore (SIN)
-- Expected: ~13,600 km
SELECT haversine_distance(
    37.6213, -122.3790,  -- SFO coordinates
    1.3644, 103.9915     -- SIN coordinates
) AS sfo_to_singapore_km;

-- ============================================
-- CALCULATE DISTANCES FOR ALL ROUTES
-- ============================================

-- Add distance calculation with progress tracking
SELECT 'Starting distance calculation for all routes...' AS status;

-- Update routes with calculated distances
-- Join to airports to get coordinates
UPDATE routes r
JOIN airports src ON r.source_airport = src.iata_code
JOIN airports dst ON r.destination_airport = dst.iata_code
SET
    r.distance_km = CAST(
        6371 * ACOS(
            LEAST(1.0, GREATEST(-1.0,
                COS(RADIANS(src.latitude)) * COS(RADIANS(dst.latitude)) *
                COS(RADIANS(dst.longitude) - RADIANS(src.longitude)) +
                SIN(RADIANS(src.latitude)) * SIN(RADIANS(dst.latitude))
            ))
        ) AS DECIMAL(10, 2) -- The parenthesis was moved to here
    )
WHERE r.distance_km IS NULL;

-- Show summary statistics
SELECT 
    'Distance calculation complete' AS status,
    COUNT(*) AS total_routes,
    COUNT(distance_km) AS routes_with_distance,
    ROUND(MIN(distance_km), 2) AS min_distance_km,
    ROUND(AVG(distance_km), 2) AS avg_distance_km,
    ROUND(MAX(distance_km), 2) AS max_distance_km
FROM routes;

-- Find shortest routes
SELECT 
    CONCAT(source_airport, ' → ', destination_airport) AS route,
    distance_km
FROM routes
WHERE distance_km IS NOT NULL
ORDER BY distance_km ASC
LIMIT 10;

-- Find longest routes
SELECT 
    CONCAT(source_airport, ' → ', destination_airport) AS route,
    distance_km
FROM routes
WHERE distance_km IS NOT NULL
ORDER BY distance_km DESC
LIMIT 10;

-- ============================================
-- VALIDATION: Compare with known distances
-- ============================================

-- Compare calculated vs. known distances
SELECT 
    'Validation Results' AS test,
    CONCAT(source_airport, ' → ', destination_airport) AS route,
    distance_km AS calculated_km,
    'Check aviation databases for actual distance' AS note
FROM routes
WHERE source_airport IN ('JFK', 'LAX', 'SFO')
  AND destination_airport IN ('LHR', 'NRT', 'SIN')
  AND distance_km IS NOT NULL
ORDER BY distance_km DESC;

-- ============================================
-- ESTIMATE FLIGHT TIME
-- ============================================

-- Add estimated flight time (assumes 800 km/h average speed)
UPDATE routes
SET flight_time_hours = ROUND(distance_km / 800.0, 2)
WHERE distance_km IS NOT NULL
  AND flight_time_hours IS NULL;

-- Show flight time distribution
SELECT 
    CASE
        WHEN flight_time_hours < 2 THEN '< 2 hours (Short-haul)'
        WHEN flight_time_hours < 6 THEN '2-6 hours (Medium-haul)'
        WHEN flight_time_hours < 12 THEN '6-12 hours (Long-haul)'
        ELSE '> 12 hours (Ultra-long-haul)'
    END AS flight_duration_category,
    COUNT(*) AS route_count,
    ROUND(AVG(distance_km), 0) AS avg_distance_km
FROM routes
WHERE flight_time_hours IS NOT NULL
GROUP BY flight_duration_category
ORDER BY MIN(flight_time_hours);
