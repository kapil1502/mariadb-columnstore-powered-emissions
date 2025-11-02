-- ===================================================================
-- SCRIPT: 02-calculate-co2-emissions.sql
-- PURPOSE: Calculate CO2 emissions per passenger for all routes
--          that are missing values, using a robust staging approach.
--          Handles duplicate rows and ensures safe updates in ColumnStore.
-- ===================================================================

USE flight_emissions;

SELECT '🌍 Starting CO2 emissions calculation...' AS status;

-- -------------------------------------------------------------------
-- STEP 1: Clean up any old staging tables
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS stage_routes_for_co2;
DROP TABLE IF EXISTS stage_co2_updates;

SELECT '🧹 Old staging tables dropped.' AS status;

-- -------------------------------------------------------------------
-- STEP 2: Stage unique routes that need CO2 calculation
--          - Only routes with distance_km NOT NULL
--          - Only routes with NULL CO2 values
--          - Ensure one row per route using MAX(distance_km)
-- -------------------------------------------------------------------
CREATE TABLE stage_routes_for_co2 ENGINE=InnoDB AS
SELECT
    route_id,
    MAX(distance_km) AS distance_km
FROM routes
WHERE distance_km IS NOT NULL
  AND co2_per_passenger_kg IS NULL
GROUP BY route_id;

SELECT CONCAT('📊 Staged ', COUNT(*), ' unique routes for CO2 calculation.') AS status
FROM stage_routes_for_co2;

-- -------------------------------------------------------------------
-- STEP 3: Calculate CO2 values using emission factors
--          - Ensure only one matching factor per route
--          - Use CAST to DECIMAL(10,2) for precision
-- -------------------------------------------------------------------
CREATE TABLE stage_co2_updates ENGINE=InnoDB AS
SELECT route_id, new_co2_value
FROM (
    SELECT
        r.route_id,
        CAST(r.distance_km * ef.co2_kg_per_passenger_km AS DECIMAL(10,2)) AS new_co2_value,
        ROW_NUMBER() OVER (
            PARTITION BY r.route_id
            ORDER BY ef.distance_min_km ASC
        ) AS rn
    FROM stage_routes_for_co2 r
    JOIN emission_factors ef
      ON r.distance_km >= ef.distance_min_km
     AND r.distance_km < ef.distance_max_km
    WHERE ef.aircraft_category IN ('Short-haul','Medium-haul','Long-haul','Regional')
) t
WHERE rn = 1;  -- keep only one row per route
-- Ensure unique route_ids in the staging table to prevent update errors
ALTER TABLE stage_co2_updates ADD PRIMARY KEY (route_id);

SELECT CONCAT('✅ Calculated CO2 for ', COUNT(*), ' routes.') AS status
FROM stage_co2_updates;

-- -------------------------------------------------------------------
-- STEP 4: Update the main routes table with calculated CO2 values
--          - Only updates rows that previously had NULL CO2
-- -------------------------------------------------------------------
UPDATE routes r
JOIN stage_co2_updates t ON r.route_id = t.route_id
SET r.co2_per_passenger_kg = t.new_co2_value;

SELECT CONCAT('✅ Updated routes table with new CO2 values.') AS status;

-- -------------------------------------------------------------------
-- STEP 5: Cleanup staging tables
-- -------------------------------------------------------------------
DROP TABLE stage_routes_for_co2;
DROP TABLE stage_co2_updates;

SELECT '🧹 Cleanup complete. CO2 emissions calculation finished.' AS status;
