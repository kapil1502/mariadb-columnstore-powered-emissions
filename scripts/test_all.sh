#!/bin/bash
# ==============================================================================
# Comprehensive Test Script for MariaDB ColumnStore Flight Emissions Project
# ==============================================================================
# Purpose: Validate all components of the project
# Usage: ./scripts/test_all.sh
# ==============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
source "$(dirname "$0")/db_config.sh"

MYSQL_CMD="sudo mariadb -u${DB_USER} -p${DB_PASS} ${DB_NAME}"
TEST_LOG="test_results_$(date +%Y%m%d_%H%M%S).log"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}TEST: $1${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# ==============================================================================
# Test 1: Database Connection
# ==============================================================================

test_database_connection() {
    print_header "Test 1: Database Connection"
    
    print_test "Can connect to MariaDB"
    if $MYSQL_CMD -e "SELECT 1;" > /dev/null 2>&1; then
        print_pass "Database connection successful"
    else
        print_fail "Cannot connect to database"
        exit 1
    fi
    
    print_test "Database exists"
    DB_EXISTS=$($MYSQL_CMD -e "SHOW DATABASES LIKE '${DB_NAME}';" | wc -l)
    if [ $DB_EXISTS -gt 1 ]; then
        print_pass "Database ${DB_NAME} exists"
    else
        print_fail "Database ${DB_NAME} not found"
        exit 1
    fi
}

# ==============================================================================
# Test 2: Table Structure
# ==============================================================================

test_table_structure() {
    print_header "Test 2: Table Structure"
    
    # List of required tables
    REQUIRED_TABLES=(
        "airlines"
        "airports"
        "routes"
        "emission_factors"
        "flight_records"
        "flight_records_innodb"
    )
    
    for table in "${REQUIRED_TABLES[@]}"; do
        print_test "Table ${table} exists"
        TABLE_EXISTS=$($MYSQL_CMD -e "SHOW TABLES LIKE '${table}';" | wc -l)
        if [ $TABLE_EXISTS -gt 1 ]; then
            print_pass "Table ${table} exists"
        else
            print_fail "Table ${table} not found"
        fi
    done
    
    # Verify ColumnStore engine
    print_test "flight_records uses ColumnStore engine"
    ENGINE=$($MYSQL_CMD -e "SELECT ENGINE FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='flight_records';" -s -N)
    if [ "$ENGINE" == "Columnstore" ]; then
        print_pass "flight_records uses ColumnStore"
    else
        print_fail "flight_records uses $ENGINE instead of ColumnStore"
    fi
    
    # Verify InnoDB engine
    print_test "flight_records_innodb uses InnoDB engine"
    ENGINE=$($MYSQL_CMD -e "SELECT ENGINE FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='flight_records_innodb';" -s -N)
    if [ "$ENGINE" == "InnoDB" ]; then
        print_pass "flight_records_innodb uses InnoDB"
    else
        print_fail "flight_records_innodb uses $ENGINE instead of InnoDB"
    fi
}

# ==============================================================================
# Test 3: Data Integrity
# ==============================================================================

test_data_integrity() {
    print_header "Test 3: Data Integrity"
    
    # Check airlines data
    print_test "Airlines table has data"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM airlines;" -s -N)
    if [ $COUNT -gt 0 ]; then
        print_pass "Airlines table has $COUNT records"
    else
        print_fail "Airlines table is empty"
    fi
    
    # Check airports data
    print_test "Airports table has data"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM airports;" -s -N)
    if [ $COUNT -gt 5000 ]; then
        print_pass "Airports table has $COUNT records"
    else
        print_fail "Airports table has insufficient data ($COUNT records)"
    fi
    
    # Check routes data
    print_test "Routes table has data"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM routes;" -s -N)
    if [ $COUNT -gt 50000 ]; then
        print_pass "Routes table has $COUNT records"
    else
        print_fail "Routes table has insufficient data ($COUNT records)"
    fi
    
    # Check flights_records data
    print_test "flight_records has sufficient data"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records;" -s -N)
    if [ $COUNT -gt 90000 ]; then
        print_pass "flight_records has $COUNT records"
    else
        print_fail "flight_records has insufficient data ($COUNT records)"
    fi
    
    # Check flight_records_innodb matches flight_records
    print_test "InnoDB and ColumnStore tables have same row count"
    CS_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records;" -s -N)
    INN_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records_innodb;" -s -N)
    if [ $CS_COUNT -eq $INN_COUNT ]; then
        print_pass "Both tables have $CS_COUNT records"
    else
        print_fail "Count mismatch: ColumnStore=$CS_COUNT, InnoDB=$INN_COUNT"
    fi
}

# ==============================================================================
# Test 4: Data Quality
# ==============================================================================

test_data_quality() {
    print_header "Test 4: Data Quality"
    
    # Check for NULL values in critical columns
    print_test "No NULL values in record_id"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records WHERE record_id IS NULL;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "No NULL record_id values"
    else
        print_fail "Found $COUNT NULL record_id values"
    fi
    
    # Check for valid CO2 values
    print_test "All CO2 values are positive"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records WHERE total_co2_kg <= 0;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All CO2 values are positive"
    else
        print_fail "Found $COUNT non-positive CO2 values"
    fi
    
    # Check for valid distances
    print_test "All distances are positive"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM routes WHERE distance_km <= 0;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All distances are positive"
    else
        print_fail "Found $COUNT non-positive distances"
    fi
    
    # Check for valid dates
    print_test "All flight dates are in valid range"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records WHERE YEAR(flight_date) < 2020 OR YEAR(flight_date) > 2025;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All flight dates are valid"
    else
        print_fail "Found $COUNT flights with invalid dates"
    fi
}

# ==============================================================================
# Test 5: Referential Integrity
# ==============================================================================

test_referential_integrity() {
    print_header "Test 5: Referential Integrity"
    
    # Check flights reference valid routes
    print_test "All flights reference valid routes"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM flight_records f LEFT JOIN routes r ON f.route_id = r.route_id WHERE r.route_id IS NULL;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All flight route_ids are valid"
    else
        print_fail "Found $COUNT flights with invalid route_id"
    fi
    
    # Check routes reference valid airports
    print_test "All routes reference valid source airports"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM routes r LEFT JOIN airports a ON r.source_airport = a.iata_code WHERE a.iata_code IS NULL;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All route source airports are valid"
    else
        print_fail "Found $COUNT routes with invalid source airport"
    fi
    
    print_test "All routes reference valid destination airports"
    COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM routes r LEFT JOIN airports a ON r.destination_airport = a.iata_code WHERE a.iata_code IS NULL;" -s -N)
    if [ $COUNT -eq 0 ]; then
        print_pass "All route destination airports are valid"
    else
        print_fail "Found $COUNT routes with invalid destination airport"
    fi
}

# ==============================================================================
# Test 6: Query Performance
# ==============================================================================

test_query_performance() {
    print_header "Test 6: Query Performance"
    
    # Simple aggregation on ColumnStore
    print_test "Simple aggregation completes quickly (< 3s)"
    START=$(date +%s)
    $MYSQL_CMD -e "SELECT source_airport, COUNT(*) AS flights, SUM(total_co2_kg)/1000 AS co2_tonnes FROM flight_records f JOIN routes r ON f.route_id = r.route_id WHERE f.flight_date >= '2024-01-01' GROUP BY source_airport LIMIT 10;" > /dev/null
    END=$(date +%s)
    DURATION=$((END - START))
    if [ $DURATION -lt 3 ]; then
        print_pass "Query completed in ${DURATION}s"
    else
        print_fail "Query too slow: ${DURATION}s (expected < 3s)"
    fi
    
    # # Window function
    # print_test "Window function query completes quickly (< 5s)"
    # START=$(date +%s)
    # $MYSQL_CMD -e "SELECT employee_id, flight_date, total_co2_kg, SUM(total_co2_kg) OVER (PARTITION BY employee_id ORDER BY flight_date) AS running_total FROM flight_records WHERE YEAR(flight_date) = 2024 LIMIT 100;" > /dev/null
    # END=$(date +%s)
    # DURATION=$((END - START))
    # if [ $DURATION -lt 5 ]; then
    #     print_pass "Query completed in ${DURATION}s"
    # else
    #     print_fail "Query too slow: ${DURATION}s (expected < 5s)"
    # fi
}

# ==============================================================================
# Test 7: Storage Efficiency
# ==============================================================================

test_storage_efficiency() {
    print_header "Test 7: Storage Efficiency"
    
    # Compare table sizes
    print_test "ColumnStore compression is working"
    
    CS_SIZE=$($MYSQL_CMD -e "SELECT ROUND(data_length/1024/1024, 2) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='flight_records';" -s -N)
    INN_SIZE=$($MYSQL_CMD -e "SELECT ROUND(data_length/1024/1024, 2) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='flight_records_innodb';" -s -N)
    
    print_info "InnoDB size: ${INN_SIZE} MB"
    print_info "ColumnStore size: ${CS_SIZE} MB"
    
    # Calculate compression ratio
    COMPRESSION=$(echo "scale=2; (1 - $CS_SIZE / $INN_SIZE) * 100" | bc)
    print_info "Compression: ${COMPRESSION}%"
    
    # Check if compression is at least 50%
    if (( $(echo "$COMPRESSION > 50" | bc -l) )); then
        print_pass "Good compression ratio: ${COMPRESSION}%"
    else
        print_fail "Poor compression: ${COMPRESSION}% (expected > 50%)"
    fi
}

# ==============================================================================
# Test 8: Functions and Procedures
# ==============================================================================

test_functions() {
    print_header "Test 8: Functions and Procedures"
    
    # Check Haversine function exists
    print_test "Haversine function exists"
    FUNC_EXISTS=$($MYSQL_CMD -e "SHOW FUNCTION STATUS WHERE Db='${DB_NAME}' AND Name='haversine_distance';" | wc -l)
    if [ $FUNC_EXISTS -gt 1 ]; then
        print_pass "haversine_distance function exists"
        
        # Test the function
        print_test "Haversine function returns valid results"
        DISTANCE=$($MYSQL_CMD -e "SELECT ROUND(haversine_distance(40.7128, -74.0060, 51.5074, -0.1278), 2);" -s -N)
        # Distance NYC to London should be around 5570 km
        if (( $(echo "$DISTANCE > 5500 && $DISTANCE < 5600" | bc -l) )); then
            print_pass "Haversine calculation correct: ${DISTANCE} km"
        else
            print_fail "Haversine calculation incorrect: ${DISTANCE} km (expected ~5570 km)"
        fi
    else
        print_fail "haversine_distance function not found"
    fi
}

# ==============================================================================
# Test 9: Use Case Queries
# ==============================================================================

test_use_case_queries() {
    print_header "Test 9: Use Case Queries"
    
    # Test corporate travel analytics query
    print_test "Corporate travel analytics query executes"
    if $MYSQL_CMD -e "SELECT cabin_class, COUNT(*) AS flights, SUM(total_co2_kg)/1000 AS co2_tonnes FROM flight_records WHERE flight_date >= '2024-01-01' GROUP BY cabin_class ORDER BY co2_tonnes DESC LIMIT 5;" > /dev/null 2>&1; then
        print_pass "Corporate query executed successfully"
    else
        print_fail "Corporate query failed"
    fi
    
    # Test airline sustainability query
    print_test "Airline sustainability query executes"
    if $MYSQL_CMD -e "WITH route_perf AS (SELECT r.source_airport, r.destination_airport, AVG(f.total_co2_kg) AS avg_co2 FROM flight_records f JOIN routes r ON f.route_id = r.route_id GROUP BY r.source_airport, r.destination_airport LIMIT 10) SELECT * FROM route_perf;" > /dev/null 2>&1; then
        print_pass "Airline query executed successfully"
    else
        print_fail "Airline query failed"
    fi
    
    # Test government policy query
    print_test "Government policy query executes"
    if $MYSQL_CMD -e "SELECT ap.country, COUNT(*) AS flights, SUM(f.total_co2_kg)/1000 AS co2_tonnes FROM flight_records f JOIN routes r ON f.route_id = r.route_id JOIN airports ap ON r.source_airport = ap.iata_code WHERE f.flight_date >= '2024-01-01' GROUP BY ap.country ORDER BY co2_tonnes DESC LIMIT 10;" > /dev/null 2>&1; then
        print_pass "Government query executed successfully"
    else
        print_fail "Government query failed"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    print_header "MariaDB ColumnStore Aviation Emissions - Comprehensive Test Suite"
    print_info "Started: $(date)"
    print_info "Logging to: $TEST_LOG"
    
    # Run all test suites
    test_database_connection
    test_table_structure
    test_data_integrity
    test_data_quality
    test_referential_integrity
    test_query_performance
    test_storage_efficiency
    test_functions
    test_partitioning
    test_use_case_queries
    
    # Print summary
    print_header "Test Summary"
    echo -e "${BLUE}Total Tests:${NC} $TESTS_TOTAL"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}Project is ready for submission.${NC}\n"
        exit 0
    else
        echo -e "\n${RED}✗ SOME TESTS FAILED${NC}"
        echo -e "${RED}Please fix the issues above before submission.${NC}\n"
        exit 1
    fi
}

# Run main function and capture output to log
main 2>&1 | tee "$TEST_LOG"