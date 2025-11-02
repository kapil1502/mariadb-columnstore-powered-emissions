-- ============================================
-- WINDOW FUNCTIONS: Advanced Analytics
-- Demonstrating ColumnStore's analytical power
-- ============================================

USE flight_emissions;

SELECT '🪟 Window Functions Demonstration' AS feature;
SELECT '===================================' AS `separator`;

-- ============================================
-- PATTERN 1: Running Totals (Year-to-Date)
-- ============================================

SELECT 'Pattern 1: Running Totals (YTD Emissions)' AS pattern;

SELECT 
    flight_date,
    SUM(total_co2_kg) AS daily_emissions,
    
    -- 🌟 Running total (cumulative sum)
    SUM(SUM(total_co2_kg)) OVER (
        ORDER BY flight_date
        ROWS UNBOUNDED PRECEDING
    ) AS ytd_emissions,
    
    -- Percentage of YTD
    ROUND(
        SUM(SUM(total_co2_kg)) OVER (ORDER BY flight_date ROWS UNBOUNDED PRECEDING) * 100.0 /
        SUM(SUM(total_co2_kg)) OVER (),
        2
    ) AS ytd_percentage

FROM flight_records
GROUP BY flight_date
ORDER BY flight_date
LIMIT 30;

-- 🎯 COPY-PASTE TIP: Replace total_co2_kg with revenue, users, sales
-- Use for: Dashboard KPIs, progress tracking, cumulative metrics

-- ============================================
-- PATTERN 2: Moving Averages (Trend Analysis)
-- ============================================

SELECT 'Pattern 2: Moving Averages (7-day, 30-day)' AS pattern;

SELECT 
    flight_date,
    SUM(total_co2_kg) AS daily_emissions,
    
    -- 🌟 7-day moving average
    ROUND(AVG(SUM(total_co2_kg)) OVER (
        ORDER BY flight_date
        ROWS 6 PRECEDING
    ), 2) AS ma_7day,
    
    -- 🌟 30-day moving average
    ROUND(AVG(SUM(total_co2_kg)) OVER (
        ORDER BY flight_date
        ROWS 29 PRECEDING
    ), 2) AS ma_30day,
    
    -- Difference from 30-day average (trend indicator)
    ROUND(
        SUM(total_co2_kg) - AVG(SUM(total_co2_kg)) OVER (
            ORDER BY flight_date ROWS 29 PRECEDING
        ),
        2
    ) AS deviation_from_ma30

FROM flight_records
GROUP BY flight_date
ORDER BY flight_date
LIMIT 50;

-- 🎯 COPY-PASTE TIP: Adjust ROWS N PRECEDING for different periods
-- Use for: Smoothing volatility, identifying trends, anomaly detection

-- ============================================
-- PATTERN 3: Ranking (Top N Analysis)
-- ============================================

SELECT 'Pattern 3: Ranking Top Routes by Emissions' AS pattern;

SELECT 
    route_id,
    CONCAT(source_airport, ' → ', destination_airport) AS route,
    total_emissions,
    
    -- 🌟 Global rank
    RANK() OVER (ORDER BY total_emissions DESC) AS global_rank,
    
    -- 🌟 Dense rank (no gaps)
    DENSE_RANK() OVER (ORDER BY total_emissions DESC) AS dense_rank,
    
    -- 🌟 Percentile
    ROUND(PERCENT_RANK() OVER (ORDER BY total_emissions DESC) * 100, 1) AS percentile

FROM (
    SELECT 
        r.route_id,
        r.source_airport,
        r.destination_airport,
        SUM(fr.total_co2_kg) AS total_emissions
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    GROUP BY r.route_id, r.source_airport, r.destination_airport
) AS route_emissions
ORDER BY total_emissions DESC
LIMIT 20;

-- 🎯 COPY-PASTE TIP: Use RANK() for top-N queries, PERCENT_RANK() for percentiles
-- Use for: Leaderboards, top performers, outlier detection

-- ============================================
-- PATTERN 4: Partition-Based Analysis
-- Ranking within groups
-- ============================================

SELECT 'Pattern 4: Top 3 Routes per Airline' AS pattern;

WITH airline_routes AS (
    SELECT 
        r.airline_code,
        al.name AS airline_name,
        CONCAT(r.source_airport, ' → ', r.destination_airport) AS route,
        SUM(fr.total_co2_kg) AS total_emissions,
        
        -- 🌟 Rank within each airline (partition)
        ROW_NUMBER() OVER (
            PARTITION BY r.airline_code 
            ORDER BY SUM(fr.total_co2_kg) DESC
        ) AS rank_in_airline
        
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    LEFT JOIN airlines al ON r.airline_code = al.iata_code
    WHERE r.airline_code IS NOT NULL
    GROUP BY r.airline_code, al.name, route
)
SELECT 
    airline_code,
    airline_name,
    route,
    ROUND(total_emissions / 1000, 2) AS emissions_tonnes,
    rank_in_airline
FROM airline_routes
WHERE rank_in_airline <= 3
ORDER BY airline_code, rank_in_airline;

-- 🎯 COPY-PASTE TIP: PARTITION BY creates independent rankings per group
-- Use for: Top N per category, departmental rankings, regional analysis

-- ============================================
-- PATTERN 5: Lead/Lag (Period Comparisons)
-- ============================================

SELECT 'Pattern 5: Month-over-Month Growth' AS pattern;

WITH monthly_data AS (
    SELECT 
        DATE_FORMAT(flight_date, '%Y-%m') AS month,
        SUM(total_co2_kg) / 1000 AS emissions_tonnes
    FROM flight_records
    GROUP BY month
)
SELECT 
    month,
    ROUND(emissions_tonnes, 2) AS current_month,
    
    -- 🌟 Previous month value
    ROUND(LAG(emissions_tonnes, 1) OVER (ORDER BY month), 2) AS previous_month,
    
    -- 🌟 Month-over-month change
    ROUND(
        emissions_tonnes - LAG(emissions_tonnes, 1) OVER (ORDER BY month),
        2
    ) AS mom_change,
    
    -- 🌟 Month-over-month growth %
    ROUND(
        (emissions_tonnes - LAG(emissions_tonnes, 1) OVER (ORDER BY month)) * 100.0 /
        LAG(emissions_tonnes, 1) OVER (ORDER BY month),
        1
    ) AS mom_growth_pct,
    
    -- 🌟 Year-over-year comparison (12 months ago)
    ROUND(LAG(emissions_tonnes, 12) OVER (ORDER BY month), 2) AS same_month_last_year,
    
    ROUND(
        (emissions_tonnes - LAG(emissions_tonnes, 12) OVER (ORDER BY month)) * 100.0 /
        LAG(emissions_tonnes, 12) OVER (ORDER BY month),
        1
    ) AS yoy_growth_pct

FROM monthly_data
ORDER BY month;

-- 🎯 COPY-PASTE TIP: LAG(col, N) looks N rows back, LEAD(col, N) looks N rows ahead
-- Use for: Period-over-period analysis, trend detection, forecasting

-- ============================================
-- PATTERN 6: Quartile Analysis
-- ============================================

SELECT 'Pattern 6: Route Emissions Distribution (Quartiles)' AS pattern;

WITH route_stats AS (
    SELECT 
        r.route_id,
        CONCAT(r.source_airport, ' → ', r.destination_airport) AS route,
        r.distance_km,
        SUM(fr.total_co2_kg) AS total_emissions
    FROM flight_records fr
    JOIN routes r ON fr.route_id = r.route_id
    GROUP BY r.route_id, route, r.distance_km
)
SELECT 
    route,
    distance_km,
    ROUND(total_emissions / 1000, 2) AS emissions_tonnes,
    
    -- 🌟 Quartile assignment
    NTILE(4) OVER (ORDER BY total_emissions) AS quartile,
    
    -- Distribution percentile
    ROUND(PERCENT_RANK() OVER (ORDER BY total_emissions) * 100, 1) AS percentile,
    
    -- Category based on quartile
    CASE NTILE(4) OVER (ORDER BY total_emissions)
        WHEN 1 THEN 'Low Emissions'
        WHEN 2 THEN 'Medium-Low Emissions'
        WHEN 3 THEN 'Medium-High Emissions'
        WHEN 4 THEN 'High Emissions'
    END AS emission_category

FROM route_stats
ORDER BY total_emissions DESC
LIMIT 50;

-- 🎯 COPY-PASTE TIP: NTILE(N) divides data into N equal groups
-- Use for: Segmentation, ABC analysis, performance buckets

-- ============================================
-- PATTERN 7: Window Frame Specification
-- Custom aggregation windows
-- ============================================

SELECT 'Pattern 7: Custom Aggregation Windows' AS pattern;

SELECT 
    flight_date,
    SUM(total_co2_kg) AS daily_emissions,
    
    -- 🌟 Current + previous 3 days
    SUM(SUM(total_co2_kg)) OVER (
        ORDER BY flight_date
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ) AS last_4days_total,
    
    -- 🌟 Centered window (previous, current, next)
    AVG(SUM(total_co2_kg)) OVER (
        ORDER BY flight_date
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS centered_3day_avg,
    
    -- 🌟 Range-based window (all rows within same month)
    SUM(SUM(total_co2_kg)) OVER (
        PARTITION BY DATE_FORMAT(flight_date, '%Y-%m')
        ORDER BY flight_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS monthly_total

FROM flight_records
GROUP BY flight_date
ORDER BY flight_date
LIMIT 30;

-- 🎯 COPY-PASTE TIP: ROWS BETWEEN defines exact window boundaries
-- Use for: Rolling calculations, centered averages, period totals

-- ============================================
-- SUMMARY: Window Functions Performance
-- ============================================

SELECT '📊 Window Functions: Performance on ColumnStore' AS summary;
SELECT '=================================================' AS `separator`;

SELECT 
    'ColumnStore excels at window functions due to:' AS note
UNION ALL SELECT '1. Columnar storage = fast sequential scans'
UNION ALL SELECT '2. Efficient sorting for ORDER BY clauses'
UNION ALL SELECT '3. Parallel processing of partitions'
UNION ALL SELECT '4. Minimal memory overhead for aggregations'
UNION ALL SELECT ''
UNION ALL SELECT '🎯 Use Cases:'
UNION ALL SELECT '  - Time-series analysis (trends, seasonality)'
UNION ALL SELECT '  - Running totals and moving averages'
UNION ALL SELECT '  - Top-N queries within categories'
UNION ALL SELECT '  - Period-over-period comparisons'
UNION ALL SELECT '  - Statistical analysis (percentiles, quartiles)';