#!/bin/bash
# Automated Performance Benchmark Script
# Runs all benchmarks and displays results

set -e

echo "🏁 MariaDB ColumnStore Performance Benchmark"
echo "==========================================="
echo ""

# Source database config
source scripts/db_config.sh

# Clean up old temp files
rm -f /tmp/bench*.csv 2>/dev/null || true

# Run benchmark suite
echo "📊 Running benchmark suite..."
echo "This will take 2-5 minutes..."
echo ""

sudo mariadb -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < sql/07_benchmark_suite.sql

echo ""
echo "✅ Benchmark complete!"
echo ""

# Display ASCII visualization of results
echo "📈 Performance Visualization"
echo "============================"
echo ""

# Query results and create ASCII bar chart
sudo mariadb -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT 
    query_name,
    MAX(CASE WHEN engine = 'InnoDB' THEN execution_time_seconds END) AS innodb_time,
    MAX(CASE WHEN engine = 'ColumnStore' THEN execution_time_seconds END) AS columnstore_time,
    ROUND(
        MAX(CASE WHEN engine = 'InnoDB' THEN execution_time_seconds END) /
        MAX(CASE WHEN engine = 'ColumnStore' THEN execution_time_seconds END),
        1
    ) AS speedup
FROM benchmark_results
WHERE execution_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY query_name
ORDER BY speedup DESC;
" | while IFS=$'\t' read -r query innodb_time cs_time speedup; do
    
    # Calculate bar lengths (scale to 50 chars max)
    innodb_bar_len=$(echo "scale=0; ($innodb_time * 50) / $innodb_time" | bc)
    cs_bar_len=$(echo "scale=0; ($cs_time * 50) / $innodb_time" | bc)
    
    # Create bars
    innodb_bar=$(printf '█%.0s' $(seq 1 $innodb_bar_len))
    cs_bar=$(printf '█%.0s' $(seq 1 $cs_bar_len))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Query: $query"
    echo "InnoDB:      $innodb_bar ${innodb_time}s"
    echo "ColumnStore: $cs_bar ${cs_time}s"
    echo "⚡ Speedup: ${speedup}x faster"
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo mariadb -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
SELECT 
    CONCAT('Average Speedup: ', 
           ROUND(AVG(speedup_factor), 1), 
           'x faster') AS summary
FROM (
    SELECT 
        query_name,
        MAX(CASE WHEN engine = 'InnoDB' THEN execution_time_seconds END) AS innodb_sec,
        MAX(CASE WHEN engine = 'ColumnStore' THEN execution_time_seconds END) AS columnstore_sec,
        MAX(CASE WHEN engine = 'InnoDB' THEN execution_time_seconds END) /
        MAX(CASE WHEN engine = 'ColumnStore' THEN execution_time_seconds END) AS speedup_factor
    FROM benchmark_results
    WHERE execution_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
    GROUP BY query_name
) AS per_query;
"

echo ""
echo "🎉 ColumnStore demonstrates significant performance advantage!"
echo "   Perfect for analytical workloads with aggregations."
echo ""