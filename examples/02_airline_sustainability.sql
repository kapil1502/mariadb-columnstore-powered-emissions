-- ============================================
-- USE CASE 2: AIRLINE SUSTAINABILITY OPERATIONS
-- Fleet optimization and route efficiency
-- ============================================

USE flight_emissions;

SELECT '✈️  Airline Sustainability Operations' AS use_case;
SELECT '====================================' AS `separator`;

-- ============================================
-- SCENARIO: Regional Airline
-- - 200+ routes operated
-- - 500+ daily flights
-- - Goal: Reduce emissions 15% by 2025
-- ============================================

-- ============================================
-- QUERY 1: Route Efficiency Analysis
-- ============================================

SELECT '📊 Query 1: Route Efficiency Benchmarking' AS `query`;

WITH top_airlines AS (
    SELECT iata_code
    FROM airlines
    ORDER BY iata_code
    LIMIT 10
),
route_performance AS (
    SELECT 
        r.route_id,
        r.airline_code,
        CONCAT(r.source_airport, ' → ', r.destination_airport) AS route,
        r.distance_km,
        r.co2_per_passenger_kg AS theoretical_co2,
        COUNT(*) AS flight_count,
        AVG(fr.passengers) AS avg_load,
        AVG(fr.co2_per_passenger_kg) AS actual_co2,
        AVG(fr.load_factor) AS avg_load_factor
    FROM routes r
    JOIN flight_records fr ON r.route_id = fr.route_id
    JOIN top_airlines ta ON r.airline_code = ta.iata_code
    GROUP BY r.route_id, r.airline_code, route, r.distance_km, r.co2_per_passenger_kg
    HAVING flight_count >= 10
)
SELECT 
    route,
    distance_km,
    flight_count,
    ROUND(avg_load, 0) AS avg_passengers,
    ROUND(avg_load_factor, 1) AS avg_load_factor_pct,
    ROUND(theoretical_co2, 2) AS theoretical_co2_kg,
    ROUND(actual_co2, 2) AS actual_co2_kg,
    ROUND((actual_co2 - theoretical_co2) / theoretical_co2 * 100, 1) AS efficiency_loss_pct,
    ROUND((actual_co2 - theoretical_co2) * avg_load * flight_count, 0) AS annual_excess_kg,
    CASE 
        WHEN (actual_co2 - theoretical_co2) / theoretical_co2 > 0.15 THEN '🔴 High Priority'
        WHEN (actual_co2 - theoretical_co2) / theoretical_co2 > 0.05 THEN '🟡 Medium Priority'
        ELSE '🟢 Efficient'
    END AS optimization_priority
FROM route_performance
WHERE actual_co2 > theoretical_co2  
ORDER BY annual_excess_kg DESC
LIMIT 20;

-- 🎯 ACTION ITEMS for Red/Yellow routes:
-- • Aircraft upgrade to more efficient model
-- • Schedule optimization (reduce empty legs)
-- • Increase load factors through pricing
-- • Consider route consolidation

-- ============================================
-- QUERY 2: Fleet Optimization Opportunities
-- ============================================

SELECT '📊 Query 2: Aircraft Type Performance' AS query;

SELECT 
    fr.aircraft_type,
    COUNT(DISTINCT fr.route_id) AS routes_served,
    COUNT(*) AS total_flights,
    ROUND(AVG(fr.passengers), 0) AS avg_passengers,
    ROUND(AVG(fr.load_factor), 1) AS avg_load_factor,
    ROUND(AVG(r.distance_km), 0) AS avg_distance_km,
    ROUND(AVG(fr.co2_per_passenger_kg), 2) AS avg_co2_per_pax_kg,
    -- Efficiency score (lower is better)
    ROUND(AVG(fr.co2_per_passenger_kg / r.distance_km * 1000), 2) AS co2_intensity_per_1000km
FROM flight_records fr
JOIN routes r ON fr.route_id = r.route_id
WHERE fr.aircraft_type IS NOT NULL
GROUP BY fr.aircraft_type
HAVING total_flights >= 50
ORDER BY co2_intensity_per_1000km ASC
LIMIT 15;

-- 🎯 INSIGHT: Identify most/least efficient aircraft in fleet

-- ============================================
-- QUERY 3: Seasonal Demand Patterns
-- ============================================

SELECT '📊 Query 3: Seasonal Emissions Pattern' AS query;

SELECT 
    DATE_FORMAT(flight_date, '%Y-%m') AS month,
    MONTHNAME(flight_date) AS month_name,
    COUNT(*) AS flights,
    ROUND(AVG(passengers), 0) AS avg_passengers,
    ROUND(AVG(load_factor), 1) AS avg_load_factor,
    ROUND(SUM(total_co2_kg) / 1000, 2) AS total_co2_tonnes,

    ROUND((SUM(total_co2_kg) - AVG(SUM(total_co2_kg)) OVER ()) / 
          AVG(SUM(total_co2_kg)) OVER () * 100, 1) AS vs_avg_pct,
    
    CASE 
        WHEN MONTH(flight_date) IN (12, 1, 7, 8) THEN 'Peak Season'
        WHEN MONTH(flight_date) IN (2, 3, 9, 10) THEN 'Shoulder Season'
        ELSE 'Low Season'
    END AS season_category

FROM flight_records
GROUP BY 
    month,
    month_name,
    CASE 
        WHEN MONTH(flight_date) IN (12, 1, 7, 8) THEN 'Peak Season'
        WHEN MONTH(flight_date) IN (2, 3, 9, 10) THEN 'Shoulder Season'
        ELSE 'Low Season'
    END
ORDER BY month;

-- 🎯 USE CASE: Capacity planning, pricing strategy, carbon budgeting

-- ============================================
-- QUERY 4: Route Network Carbon Intensity
-- ============================================

SELECT '📊 Query 4: Hub Airport Carbon Analysis' AS query;

SELECT 
    src.iata_code AS airport,
    src.name AS airport_name,
    src.city,
    src.country,
    COUNT(DISTINCT r.route_id) AS outbound_routes,
    COUNT(*) AS total_flights,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS total_co2_tonnes,
    ROUND(AVG(r.distance_km), 0) AS avg_route_distance,
    -- Rank by emissions
    RANK() OVER (ORDER BY SUM(fr.total_co2_kg) DESC) AS emission_rank
FROM flight_records fr
JOIN routes r ON fr.route_id = r.route_id
JOIN airports src ON r.source_airport = src.iata_code
GROUP BY src.iata_code, src.name, src.city, src.country
HAVING outbound_routes >= 10
ORDER BY total_co2_tonnes DESC
LIMIT 20;

-- 🎯 INSIGHT: Focus sustainability efforts on high-emission hubs

-- ============================================
-- QUERY 5: Competitive Benchmarking
-- ============================================

SELECT '📊 Query 5: Airline Efficiency Comparison' AS query;

WITH airline_metrics AS (
    SELECT 
        r.airline_code,
        al.name AS airline_name,
        COUNT(*) AS total_flights,
        ROUND(AVG(fr.passengers), 0) AS avg_passengers,
        ROUND(AVG(fr.load_factor), 1) AS avg_load_factor,
        ROUND(AVG(fr.co2_per_passenger_kg), 2) AS avg_co2_per_pax,
        ROUND(SUM(fr.total_co2_kg) / 1000000, 3) AS total_co2_megatonnes
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    LEFT JOIN airlines al ON r.airline_code = al.iata_code
    WHERE r.airline_code IS NOT NULL
    GROUP BY r.airline_code, al.name
    HAVING total_flights >= 100
)
SELECT 
    airline_name,
    total_flights,
    avg_passengers,
    avg_load_factor,
    avg_co2_per_pax,
    total_co2_megatonnes,
    -- Percentile ranking
    ROUND(PERCENT_RANK() OVER (ORDER BY avg_co2_per_pax) * 100, 0) AS efficiency_percentile,
    -- Category
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY avg_co2_per_pax) < 0.25 THEN '⭐ Top 25% Efficient'
        WHEN PERCENT_RANK() OVER (ORDER BY avg_co2_per_pax) > 0.75 THEN '⚠️  Bottom 25%'
        ELSE '📊 Average'
    END AS efficiency_category
FROM airline_metrics
ORDER BY avg_co2_per_pax ASC
LIMIT 20;

-- 🎯 USE CASE: Industry benchmarking, investor relations, marketing

-- ============================================
-- QUERY 6: Carbon Reduction Goal Tracking
-- ============================================

SELECT '📊 Query 6: Progress Toward 15% Reduction Goal' AS query;

SELECT 
    q.quarter_num,
    CONCAT('Q', q.quarter_num) AS quarter,
    q.flights,
    ROUND(q.avg_co2, 2) AS avg_co2_per_flight,
    ROUND(@baseline_avg, 2) AS baseline_avg,
    ROUND(
        (q.avg_co2 - @baseline_avg) / @baseline_avg * 100, 
    2) AS vs_baseline_pct,
    ROUND(@baseline_avg * 0.85, 2) AS target_avg,
    CASE 
        WHEN q.avg_co2 <= @baseline_avg * 0.85 THEN '✅ Goal Achieved'
        WHEN q.avg_co2 <= @baseline_avg * 0.90 THEN '🟡 On Track'
        ELSE '🔴 Behind Target'
    END AS status
FROM (
    -- Inner query: Perform all aggregations here
    SELECT 
        QUARTER(flight_date) AS quarter_num,
        COUNT(*) AS flights,
        AVG(total_co2_kg) AS avg_co2
    FROM 
        flight_records
    GROUP BY 
        QUARTER(flight_date)  -- Grouping is simple here
) AS q
ORDER BY 
    q.quarter_num;

-- 🎯 GOAL: 15% reduction = switching to more efficient aircraft/operations

-- ============================================
-- SUMMARY: Airline Benefits
-- ============================================

SELECT '✈️  Airline Sustainability Benefits' AS summary;
SELECT '====================================' AS `separator`;

SELECT 'Operational Benefits:' AS category
UNION ALL SELECT '✓ Identify inefficient routes for optimization'
UNION ALL SELECT '✓ Fleet planning based on carbon performance'
UNION ALL SELECT '✓ Benchmark against competitors'
UNION ALL SELECT '✓ Track progress toward carbon goals'
UNION ALL SELECT '✓ Support CORSIA compliance reporting'
UNION ALL SELECT '✓ Hub-level carbon management'
UNION ALL SELECT ''
UNION ALL SELECT 'Business Value:'
UNION ALL SELECT '• Fuel efficiency = cost savings (1% improvement = $M annually)'
UNION ALL SELECT '• Sustainability marketing advantage'
UNION ALL SELECT '• Regulatory compliance (EU ETS, CORSIA)'
UNION ALL SELECT '• Investor confidence (ESG ratings)'
UNION ALL SELECT ''
UNION ALL SELECT 'ColumnStore Performance:'
UNION ALL SELECT '• Analyze 500+ daily flights in real-time'
UNION ALL SELECT '• Complex route efficiency queries < 2 seconds'
UNION ALL SELECT '• Scale to years of historical data';