-- ============================================
-- USE CASE 3: GOVERNMENT POLICY & REGULATION
-- National aviation emissions monitoring
-- ============================================

USE flight_emissions;

SELECT '🏛️  Government Aviation Policy Analytics' AS use_case;
SELECT '=========================================' AS `separator`;

-- ============================================
-- SCENARIO: National Aviation Authority
-- - Monitor domestic + international flights
-- - Support climate policy development
-- - Paris Agreement compliance reporting
-- ============================================

-- ============================================
-- QUERY 1: National Aviation Emissions Inventory
-- ============================================

SELECT '📊 Query 1: National Emissions Inventory' AS query;

WITH country_flights AS (
    SELECT 
        src.country AS origin_country,
        dst.country AS destination_country,
        CASE 
            WHEN src.country = dst.country THEN 'Domestic'
            ELSE 'International'
        END AS flight_type,
        COUNT(*) AS flight_count,
        SUM(fr.total_co2_kg) AS total_co2_kg
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    JOIN airports src ON r.source_airport = src.iata_code
    JOIN airports dst ON r.destination_airport = dst.iata_code
    GROUP BY origin_country, destination_country, flight_type
)
SELECT 
    origin_country,
    SUM(CASE WHEN flight_type = 'Domestic' THEN flight_count ELSE 0 END) AS domestic_flights,
    SUM(CASE WHEN flight_type = 'International' THEN flight_count ELSE 0 END) AS intl_flights,
    ROUND(SUM(CASE WHEN flight_type = 'Domestic' THEN total_co2_kg ELSE 0 END) / 1000, 2) AS domestic_co2_tonnes,
    ROUND(SUM(CASE WHEN flight_type = 'International' THEN total_co2_kg ELSE 0 END) / 1000, 2) AS intl_co2_tonnes,
    ROUND(SUM(total_co2_kg) / 1000, 2) AS total_co2_tonnes,
    -- Per capita (assuming population data available)
    ROUND(SUM(total_co2_kg) / 1000000, 3) AS total_co2_megatonnes
FROM country_flights
GROUP BY origin_country
HAVING total_co2_tonnes > 100
ORDER BY total_co2_tonnes DESC
LIMIT 20;

-- 🎯 USE CASE: UN Climate reporting, national GHG inventories

-- ============================================
-- QUERY 2: International Aviation Emissions Matrix
-- ============================================

SELECT '📊 Query 2: Bilateral Emissions (Country Pairs)' AS query;

SELECT 
    src.country AS from_country,
    dst.country AS to_country,
    COUNT(DISTINCT r.route_id) AS routes,
    COUNT(*) AS flights,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS total_co2_tonnes,
    ROUND(AVG(r.distance_km), 0) AS avg_distance_km
FROM flight_records fr
JOIN routes r ON fr.route_id = r.route_id
JOIN airports src ON r.source_airport = src.iata_code
JOIN airports dst ON r.destination_airport = dst.iata_code
WHERE src.country != dst.country  -- International only
  AND src.country IN ('United States', 'United Kingdom', 'Germany', 'France', 'China')
  AND dst.country IN ('United States', 'United Kingdom', 'Germany', 'France', 'China')
GROUP BY from_country, to_country
ORDER BY total_co2_tonnes DESC
LIMIT 30;

-- 🎯 USE CASE: Bilateral climate agreements, international cooperation

-- ============================================
-- QUERY 3: Policy Impact Assessment
-- ============================================

SELECT '📊 Query 3: Carbon Tax Impact Simulation' AS query;

-- Simulate carbon pricing policy ($50/tonne CO2)
WITH route_economics AS (
    SELECT 
        r.route_id,
        CONCAT(src.city, ' → ', dst.city) AS route,
        src.country AS origin_country,
        r.distance_km,
        COUNT(*) AS annual_flights,
        AVG(fr.passengers) AS avg_passengers,
        ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS annual_co2_tonnes,
        -- Current ticket price estimate ($0.15/km)
        ROUND(AVG(r.distance_km * 0.15 * fr.passengers), 0) AS current_revenue_per_flight,
        -- Carbon tax cost ($50/tonne)
        ROUND(SUM(fr.total_co2_kg) / COUNT(*) * 50 / 1000, 2) AS carbon_tax_per_flight,
        -- Price increase needed
        ROUND((SUM(fr.total_co2_kg) / COUNT(*) * 50 / 1000) / 
              AVG(fr.passengers), 2) AS price_increase_per_passenger
    FROM routes r
    JOIN flight_records fr ON r.route_id = fr.route_id
    JOIN airports src ON r.source_airport = src.iata_code
    JOIN airports dst ON r.destination_airport = dst.iata_code
    WHERE src.country = 'United States'  -- Policy applies to US origin
    GROUP BY r.route_id, route, origin_country, r.distance_km
    HAVING annual_flights >= 10
)
SELECT 
    route,
    distance_km,
    annual_flights,
    ROUND(avg_passengers, 0) AS avg_passengers,
    annual_co2_tonnes,
    current_revenue_per_flight,
    carbon_tax_per_flight,
    price_increase_per_passenger,
    ROUND(price_increase_per_passenger / (current_revenue_per_flight / avg_passengers) * 100, 1) AS price_increase_pct,
    CASE 
        WHEN price_increase_per_passenger > 50 THEN '🔴 High Impact'
        WHEN price_increase_per_passenger > 20 THEN '🟡 Medium Impact'
        ELSE '🟢 Low Impact'
    END AS policy_impact
FROM route_economics
ORDER BY annual_co2_tonnes DESC
LIMIT 20;

-- 🎯 USE CASE: Policy design, economic impact assessment

-- ============================================
-- QUERY 4: Regional Emissions Trends
-- ============================================

SELECT '📊 Query 4: Geographic Emissions Distribution' AS query;

WITH regional_data AS (
    SELECT 
        src.country,
        CASE 
            WHEN src.country IN ('United States', 'Canada', 'Mexico') THEN 'North America'
            WHEN src.country IN ('United Kingdom', 'Germany', 'France', 'Italy', 'Spain') THEN 'Europe'
            WHEN src.country IN ('China', 'Japan', 'South Korea', 'India') THEN 'Asia'
            WHEN src.country IN ('Brazil', 'Argentina', 'Chile') THEN 'South America'
            ELSE 'Other'
        END AS region,
        DATE_FORMAT(fr.flight_date, '%Y-%m') AS month,
        SUM(fr.total_co2_kg) AS monthly_co2_kg
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    JOIN airports src ON r.source_airport = src.iata_code
    GROUP BY src.country, region, month
)
SELECT 
    region,
    COUNT(DISTINCT country) AS countries,
    ROUND(SUM(monthly_co2_kg) / 1000, 2) AS total_co2_tonnes,
    ROUND(AVG(monthly_co2_kg) / 1000, 2) AS avg_monthly_tonnes,
    -- Percentage of global
    ROUND(SUM(monthly_co2_kg) * 100.0 / SUM(SUM(monthly_co2_kg)) OVER (), 1) AS pct_of_global
FROM regional_data
GROUP BY region
ORDER BY total_co2_tonnes DESC;

-- 🎯 USE CASE: Regional policy coordination, climate negotiations
-- ============================================
-- QUERY 5: Compliance Tracking (CORSIA)
-- ============================================
SELECT '📊 Query 5: CORSIA Compliance Reporting' AS query;
-- CORSIA: Carbon Offsetting and Reduction Scheme for International Aviation
-- Step 1: Compute baseline and store in a variable

DROP TABLE IF EXISTS corsia_baseline;
CREATE TABLE corsia_baseline AS
SELECT AVG(total_co2_kg) AS baseline_avg
FROM flight_records
WHERE YEAR(flight_date) = 2024;

SET @baseline_avg = (SELECT AVG(total_co2_kg) FROM flight_records);

-- Step 2: Use it in your main aggregation query
SELECT
    YEAR(flight_date) AS year,
    COUNT(*) AS flights,
    ROUND(SUM(total_co2_kg) / 1000000, 3) AS actual_megatonnes,
    ROUND(@baseline_avg * COUNT(*) / 1000000, 3) AS baseline_megatonnes,
    ROUND(SUM(total_co2_kg) / 1000000 - @baseline_avg * COUNT(*) / 1000000, 3) AS excess_megatonnes,
    ROUND((SUM(total_co2_kg) / 1000000 - @baseline_avg * COUNT(*) / 1000000) * 1000, 0) AS offset_tonnes_required,
    ROUND((SUM(total_co2_kg) / 1000000 - @baseline_avg * COUNT(*) / 1000000) * 1000 * 15, 0) AS estimated_offset_cost_usd
FROM flight_records
GROUP BY year
ORDER BY year;

-- 🎯 USE CASE: ICAO CORSIA reporting, carbon credit purchases
-- ============================================
-- SUMMARY: Government Benefits
-- ============================================
SELECT '🏛️  Government Policy Analytics Benefits' AS summary;
SELECT '==========================================' AS `separator`;
SELECT 'Policy Benefits:' AS category
UNION ALL SELECT '✓ National GHG inventory for aviation sector'
UNION ALL SELECT '✓ Evidence-based policy development'
UNION ALL SELECT '✓ International climate agreement reporting'
UNION ALL SELECT '✓ Economic impact assessment of carbon pricing'
UNION ALL SELECT '✓ CORSIA compliance monitoring'
UNION ALL SELECT '✓ Regional emissions tracking'
UNION ALL SELECT ''
UNION ALL SELECT 'Data-Driven Decisions:'
UNION ALL SELECT '• Design effective carbon taxes/cap-and-trade'
UNION ALL SELECT '• Monitor progress toward Paris Agreement goals'
UNION ALL SELECT '• Support international climate negotiations'
UNION ALL SELECT '• Public transparency and accountability'
UNION ALL SELECT ''
UNION ALL SELECT 'System Performance:'
UNION ALL SELECT '• Analyze entire national aviation sector'
UNION ALL SELECT '• Process years of data in seconds'
UNION ALL SELECT '• Real-time policy impact simulation';