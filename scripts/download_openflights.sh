#!/bin/bash
# Download OpenFlights dataset

set -e

echo "📥 Downloading OpenFlights dataset..."

# Create data directory
mkdir -p data/openflights

cd data/openflights

# Download datasets
echo "Downloading airlines..."
wget -O airlines.dat "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat"

echo "Downloading airports..."
wget -O airports.dat "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat"

echo "Downloading routes..."
wget -O routes.dat "https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat"

echo "✅ Download complete!"
echo ""
echo "Files downloaded:"
ls -lh *.dat

cd ../..
