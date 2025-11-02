-- ============================================
-- USE CASE 1: CORPORATE TRAVEL ANALYTICS
-- Track business travel carbon footprint
-- ============================================

USE flight_emissions;

SELECT '🏢 Corporate Travel Carbon Tracking' AS use_case;
SELECT '====================================' AS `separator`;

-- ============================================
-- SCENARIO: Fortune 500 Company
-- - 10,000 employees
-- - 50,000 business flights per year
-- - Need to track emissions by department
-- ============================================

-- Simulate corporate metadata (normally from booking system)
DROP TABLE IF EXISTS corporate_flights;

CREATE TABLE corporate_flights (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    record_id BIGINT,
    employee_id VARCHAR(10),
    department VARCHAR(50),
    cost_center VARCHAR(20),
    trip_purpose VARCHAR(100),
    booking_date DATE,
    INDEX (record_id)
) ENGINE=InnoDB;

-- Generate sample corporate data
INSERT INTO corporate_flights (record_id, employee_id, department, cost_center, trip_purpose, booking_date)
SELECT 
    record_id,
    CONCAT('EMP', LPAD(FLOOR(1 + RAND() * 10000), 5, '0')) AS employee_id,
    ELT(FLOOR(1 + RAND() * 5), 'Sales', 'Engineering', 'Marketing', 'Operations', 'Executive') AS department,
    CONCAT('CC', LPAD(FLOOR(1 + RAND() * 100), 3, '0')) AS cost_center,
    ELT(FLOOR(1 + RAND() * 4), 'Client Meeting', 'Conference', 'Training', 'Site Visit') AS trip_purpose,
    DATE_SUB(flight_date, INTERVAL FLOOR(RAND() * 30) DAY) AS booking_date
FROM flight_records
LIMIT 50000;

SELECT CONCAT('✅ Generated ', COUNT(*), ' corporate bookings') AS status FROM corporate_flights;

-- ============================================
-- QUERY 1: Department Carbon Footprint
-- ============================================

SELECT '📊 Query 1: Emissions by Department' AS query;

SELECT 
    cf.department,
    COUNT(DISTINCT cf.employee_id) AS employees_traveled,
    COUNT(*) AS total_flights,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS total_co2_tonnes,
    ROUND(AVG(fr.total_co2_kg), 2) AS avg_co2_per_flight_kg,
    ROUND(SUM(fr.total_co2_kg) / COUNT(DISTINCT cf.employee_id), 2) AS co2_per_employee_kg
FROM corporate_flights cf
JOIN flight_records fr ON cf.record_id = fr.record_id
GROUP BY cf.department
ORDER BY total_co2_tonnes DESC;

-- 🎯 COPY-PASTE TIP: Replace 'department' with your grouping dimension
-- Use for: Regional analysis, project tracking, client reporting

-- ============================================
-- QUERY 2: Top Emitting Routes (For Optimization)
-- ============================================

SELECT '📊 Query 2: Top 10 Routes by Corporate Travel' AS query;

SELECT 
    CONCAT(r.source_airport, ' → ', r.destination_airport) AS route,
    CONCAT(src.city, ' → ', dst.city) AS cities,
    COUNT(*) AS trips_per_year,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS annual_co2_tonnes,
    ROUND(AVG(fr.total_co2_kg), 0) AS avg_co2_per_trip_kg,
    r.distance_km,
    -- 🌟 Calculate potential savings with 20% reduction
    ROUND(SUM(fr.total_co2_kg) * 0.20 / 1000, 2) AS potential_savings_tonnes
FROM corporate_flights cf
JOIN flight_records fr ON cf.record_id = fr.record_id
JOIN routes r ON fr.route_id = r.route_id
JOIN airports src ON r.source_airport = src.iata_code
JOIN airports dst ON r.destination_airport = dst.iata_code
GROUP BY route, cities, r.distance_km
HAVING trips_per_year >= 10
ORDER BY annual_co2_tonnes DESC
LIMIT 10;

-- 🎯 ACTION: These routes are candidates for:
-- • Virtual meeting alternatives
-- • Train travel (if < 500km)
-- • Consolidating trips
-- • Carbon offset programs

-- ============================================
-- QUERY 3: Monthly Trend with Budget Tracking
-- ============================================

SELECT '📊 Query 3: Monthly Emissions vs Budget' AS query;

WITH monthly_data AS (
    SELECT 
        DATE_FORMAT(fr.flight_date, '%Y-%m') AS month,
        SUM(fr.total_co2_kg) / 1000 AS actual_tonnes
    FROM corporate_flights cf
    JOIN flight_records fr ON cf.record_id = fr.record_id
    GROUP BY month
)
SELECT 
    month,
    ROUND(actual_tonnes, 2) AS actual_co2_tonnes,
    10.0 AS monthly_budget_tonnes,  -- Company target: 10 tonnes/month
    ROUND(actual_tonnes - 10.0, 2) AS variance_tonnes,
    ROUND((actual_tonnes - 10.0) / 10.0 * 100, 1) AS variance_pct,
    CASE 
        WHEN actual_tonnes > 10.0 THEN '⚠️  Over Budget'
        WHEN actual_tonnes > 9.5 THEN '⚡ Near Budget'
        ELSE '✅ Within Budget'
    END AS status,
    -- Running YTD total
    ROUND(SUM(actual_tonnes) OVER (ORDER BY month), 2) AS ytd_tonnes
FROM monthly_data
ORDER BY month;

-- 🎯 USE CASE: Executive dashboard, board presentations, ESG reporting

-- ============================================
-- QUERY 4: Employee Travel Patterns
-- ============================================

SELECT '📊 Query 4: Frequent Traveler Analysis' AS query;

WITH employee_stats AS (
    SELECT 
        cf.employee_id,
        cf.department,
        COUNT(*) AS trip_count,
        SUM(fr.total_co2_kg) AS total_co2_kg,
        AVG(r.distance_km) AS avg_trip_distance
    FROM corporate_flights cf
    JOIN flight_records fr ON cf.record_id = fr.record_id
    JOIN routes r ON fr.route_id = r.route_id
    GROUP BY cf.employee_id, cf.department
)
SELECT 
    department,
    COUNT(*) AS frequent_travelers,
    ROUND(AVG(trip_count), 1) AS avg_trips_per_person,
    ROUND(SUM(total_co2_kg) / 1000, 2) AS dept_total_tonnes,
    ROUND(AVG(total_co2_kg), 0) AS avg_co2_per_person_kg
FROM employee_stats
WHERE trip_count >= 5  -- Frequent travelers: 5+ trips
GROUP BY department
ORDER BY dept_total_tonnes DESC;

-- 🎯 INSIGHT: Identify departments needing travel policy review

-- ============================================
-- QUERY 5: Cost vs Carbon Analysis
-- ============================================

SELECT '📊 Query 5: Travel Cost vs Carbon Impact' AS query;

-- Simulate ticket costs (normally from booking system)
SELECT 
    cf.department,
    COUNT(*) AS total_trips,
    -- Estimated costs ($0.50/km as proxy)
    ROUND(SUM(r.distance_km * 0.50), 0) AS estimated_cost_usd,
    ROUND(SUM(fr.total_co2_kg) / 1000, 2) AS total_co2_tonnes,
    -- Cost per tonne of CO2
    ROUND(SUM(r.distance_km * 0.50) / (SUM(fr.total_co2_kg) / 1000), 0) AS cost_per_tonne_usd,
    -- Carbon intensity (kg CO2 per dollar spent)
    ROUND(SUM(fr.total_co2_kg) / SUM(r.distance_km * 0.50), 2) AS kg_co2_per_dollar
FROM corporate_flights cf
JOIN flight_records fr ON cf.record_id = fr.record_id
JOIN routes r ON fr.route_id = r.route_id
GROUP BY cf.department
ORDER BY total_co2_tonnes DESC;

-- 🎯 BUSINESS VALUE: Optimize both cost AND carbon footprint

-- ============================================
-- QUERY 6: Quarter-over-Quarter Growth
-- ============================================

SELECT '📊 Query 6: Quarterly Trend Analysis' AS query;

WITH quarterly_data AS (
    SELECT 
        YEAR(fr.flight_date) AS year,
        QUARTER(fr.flight_date) AS quarter,
        COUNT(*) AS flights,
        SUM(fr.total_co2_kg) / 1000 AS co2_tonnes
    FROM corporate_flights cf
    JOIN flight_records fr ON cf.record_id = fr.record_id
    GROUP BY year, quarter
)
SELECT 
    CONCAT(year, '-Q', quarter) AS period,
    flights,
    ROUND(co2_tonnes, 2) AS co2_tonnes,
    -- Quarter-over-quarter change
    ROUND(co2_tonnes - LAG(co2_tonnes) OVER (ORDER BY year, quarter), 2) AS qoq_change,
    ROUND((co2_tonnes - LAG(co2_tonnes) OVER (ORDER BY year, quarter)) / 
          LAG(co2_tonnes) OVER (ORDER BY year, quarter) * 100, 1) AS qoq_growth_pct
FROM quarterly_data
ORDER BY year, quarter;

-- 🎯 USE CASE: Track progress toward reduction goals

-- ============================================
-- SUMMARY: Corporate Benefits
-- ============================================

SELECT '💼 Corporate Travel Analytics Benefits' AS summary;
SELECT '=======================================' AS `separator`;

SELECT 'Benefits:' AS category
UNION ALL SELECT '✓ Real-time visibility into travel carbon footprint'
UNION ALL SELECT '✓ Department-level accountability'
UNION ALL SELECT '✓ Identify high-emission routes for optimization'
UNION ALL SELECT '✓ Track progress toward net-zero goals'
UNION ALL SELECT '✓ Support ESG reporting (Scope 3 emissions)'
UNION ALL SELECT '✓ Inform travel policy decisions'
UNION ALL SELECT ''
UNION ALL SELECT 'ROI Examples:'
UNION ALL SELECT '• 20% reduction in travel = $500K+ savings + 1,000 tonnes CO2'
UNION ALL SELECT '• Avoid 1 transatlantic flight = 1.5 tonnes CO2 saved'
UNION ALL SELECT '• Virtual meetings vs travel = 90%+ carbon reduction'
UNION ALL SELECT ''
UNION ALL SELECT 'Query Performance:'
UNION ALL SELECT '• All queries < 2 seconds on 50K bookings'
UNION ALL SELECT '• ColumnStore enables real-time dashboards'
UNION ALL SELECT '• Scales to millions of trips';