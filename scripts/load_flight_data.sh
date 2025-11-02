#!/bin/bash
# Load flight records data using cpimport
# This script loads CSV data into the flight_records table using ColumnStore's cpimport utility

set -e  # Exit on error

echo "🚀 Loading flight records using cpimport..."
echo "=========================================="

# Configuration
DB_NAME="flight_emissions"
TABLE_NAME="flight_records"

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CSV_FILE="$PROJECT_ROOT/data/flight_records.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ CSV file not found: $CSV_FILE"
    echo "Please ensure the CSV file exists before running this script."
    echo "You can generate it using: python3 scripts/generate_flight_data_csv.py"
    exit 1
fi

# Get file info
FILE_SIZE=$(du -h "$CSV_FILE" | cut -f1)
LINE_COUNT=$(wc -l < "$CSV_FILE")

echo "📊 CSV File Information:"
echo "   File: $CSV_FILE"
echo "   Size: $FILE_SIZE"
echo "   Lines: $LINE_COUNT"
echo ""

# Check if table exists and is empty
echo "🔍 Checking target table..."
EXISTING_ROWS=$(mysql -u root -p$DB_PASS -e "SELECT COUNT(*) FROM $DB_NAME.$TABLE_NAME;" -s -N 2>/dev/null || echo "0")

if [ "$EXISTING_ROWS" -gt 0 ]; then
    echo "⚠️  Table $TABLE_NAME already contains $EXISTING_ROWS rows."
    read -p "Do you want to truncate the table first? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Truncating table..."
        mysql -u root -p$DB_PASS -e "TRUNCATE TABLE $DB_NAME.$TABLE_NAME;"
        echo "✅ Table truncated."
    else
        echo "⚠️  Proceeding with existing data. This may cause duplicates."
    fi
fi

# Run cpimport
echo "📥 Starting data import..."
echo "Command: sudo cpimport -s ',' -E '\"' $DB_NAME $TABLE_NAME $CSV_FILE"
echo ""

# Execute cpimport with error handling
if sudo cpimport -s ',' -E '"' "$DB_NAME" "$TABLE_NAME" "$CSV_FILE"; then
    echo ""
    echo "✅ Data loading complete!"
    
    # Verify the import
    echo "🔍 Verifying import..."
    NEW_ROWS=$(mysql -u root -p$DB_PASS -e "SELECT COUNT(*) FROM $DB_NAME.$TABLE_NAME;" -s -N 2>/dev/null || echo "0")
    echo "📊 Total rows in table: $NEW_ROWS"
    
    # Show sample data
    echo ""
    echo "📋 Sample data (first 5 rows):"
    mysql -u root -p$DB_PASS -e "SELECT * FROM $DB_NAME.$TABLE_NAME LIMIT 5;" 2>/dev/null || echo "Could not retrieve sample data"
    
else
    echo ""
    echo "❌ Data import failed!"
    echo "Common issues:"
    echo "1. CSV file format doesn't match table schema"
    echo "2. Permission issues with cpimport"
    echo "3. ColumnStore service not running"
    echo "4. Database or table doesn't exist"
    echo ""
    echo "Troubleshooting:"
    echo "- Check ColumnStore status: sudo systemctl status mariadb-columnstore-cmapi"
    echo "- Verify table exists: mysql -e 'DESCRIBE $DB_NAME.$TABLE_NAME;'"
    echo "- Check CSV format matches table schema"
    exit 1
fi

echo ""
echo "🎉 Flight data loading completed successfully!"
echo "You can now run the analytics queries in the examples/ directory."
