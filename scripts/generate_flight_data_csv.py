#!/usr/bin/env python3
"""
Flight Data Generator for MariaDB ColumnStore

This script generates synthetic flight records and saves them to a CSV file,
which can be efficiently loaded using ColumnStore's LOAD DATA INFILE.
"""

import csv
import os
import random
from datetime import datetime, timedelta
from tqdm import tqdm

# Configuration
CONFIG = {
    'output_file': 'data/flight_records.csv',
    'total_records': 1_000_000,  # Target number of records
    'batch_size': 100_000,       # Records per batch (for progress tracking)
    'start_date': '2024-01-01',
    'end_date': '2024-12-31',
}

class FlightDataGeneratorCSV:
    """Generates realistic flight data and saves to CSV."""
    
    def __init__(self, config: dict):
        self.config = config
        self.aircraft_types = [
            'A320', 'B737', 'A321', 'B738', 'A319', 'B739', 'A20N', 'B38M', 'A21N', 'B789',
            'A359', 'B77W', 'B788', 'A333', 'A350', 'B772', 'B77L', 'A332', 'B763', 'A306'
        ]
        self.airline_codes = ['AA', 'DL', 'UA', 'BA', 'LH', 'AF', 'EK', 'SQ', 'QF', 'JL']
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(config['output_file']), exist_ok=True)
    
    def generate_flight_record(self, record_id: int, route_id: int) -> dict:
        """Generate a single flight record with realistic data matching the table schema."""
        # Generate random date within range
        start_date = datetime.strptime(self.config['start_date'], '%Y-%m-%d')
        end_date = datetime.strptime(self.config['end_date'], '%Y-%m-%d')
        date_range = (end_date - start_date).days
        flight_date = start_date + timedelta(days=random.randint(0, date_range))
        
        # Generate flight number (e.g., AA123)
        airline = random.choice(self.airline_codes)
        flight_number = f"{airline}{random.randint(100, 9999):04d}"[:10]  # Ensure max 10 chars
        
        # Aircraft type
        aircraft_type = random.choice(self.aircraft_types)
        
        # Determine cabin class
        rand_val = random.randint(1, 100)
        if rand_val < 85:
            cabin_class = 'economy'
        elif rand_val < 97:
            cabin_class = 'business'
        else:
            cabin_class = 'first'
        
        # Generate realistic values based on aircraft type and cabin class
        if 'A3' in aircraft_type or 'B73' in aircraft_type:  # Narrow-body
            max_pax = random.randint(150, 220)
            base_co2 = random.randint(80, 120)
        else:  # Wide-body
            max_pax = random.randint(250, 400)
            base_co2 = random.randint(150, 250)
        
        # Adjust for cabin class
        if cabin_class == 'business':
            max_pax = int(max_pax * 0.6)
            base_co2 = int(base_co2 * 1.5)
        elif cabin_class == 'first':
            max_pax = int(max_pax * 0.3)
            base_co2 = int(base_co2 * 2.0)
        
        # Generate passengers and load factor
        load_factor = round(random.uniform(60.0, 95.0), 2)  # 60-95% load factor
        passengers = int(max_pax * (load_factor / 100))
        
        # Calculate CO2 values (as integers for BIGINT)
        co2_per_pax = base_co2
        total_co2 = passengers * co2_per_pax
        
        # Current timestamp for created_at
        created_at = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        return {
            'record_id': record_id,
            'route_id': route_id,
            'flight_date': flight_date.strftime('%Y-%m-%d'),
            'flight_number': flight_number,
            'aircraft_type': aircraft_type,
            'passengers': passengers,
            'load_factor': f"{load_factor:.2f}",  # Format with 2 decimal places
            'cabin_class': cabin_class,
            'total_co2_kg': total_co2,
            'co2_per_passenger_kg': co2_per_pax,
            'created_at': created_at
        }
    
    def generate_to_csv(self):
        """Generate flight records and save to CSV."""
        print(f"🚀 Generating {self.config['total_records']:,} flight records")
        print(f"📅 Date range: {self.config['start_date']} to {self.config['end_date']}")
        
        # CSV headers - must match the table structure exactly
        fieldnames = [
            'record_id',
            'route_id',
            'flight_date',
            'flight_number',
            'aircraft_type',
            'passengers',
            'load_factor',
            'cabin_class',
            'total_co2_kg',
            'co2_per_passenger_kg',
            'created_at'
        ]
        
        # Create output directory if it doesn't exist
        os.makedirs(os.path.dirname(self.config['output_file']), exist_ok=True)
        
        with open(self.config['output_file'], 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            
            with tqdm(total=self.config['total_records'], desc="Generating records") as pbar:
                for i in range(1, self.config['total_records'] + 1):
                    # Generate a route_id (1-10,000 for this example)
                    route_id = random.randint(1, 10000)
                    
                    # Generate and write the record
                    record = self.generate_flight_record(i, route_id)
                    writer.writerow(record)
                    
                    # Update progress
                    if i % self.config['batch_size'] == 0:
                        pbar.update(self.config['batch_size'])
                        csvfile.flush()  # Ensure data is written to disk
        
        print(f"\n✅ Successfully generated {self.config['total_records']:,} flight records")
        print(f"💾 Saved to: {os.path.abspath(self.config['output_file'])}")
        
        # Print file size
        file_size = os.path.getsize(self.config['output_file']) / (1024 * 1024)  # MB
        print(f"📊 File size: {file_size:.2f} MB")

def main():
    """Main function to run the data generation process."""
    # Create output directory if it doesn't exist
    os.makedirs('data', exist_ok=True)
    
    # Initialize and run generator
    generator = FlightDataGeneratorCSV(CONFIG)
    
    try:
        start_time = datetime.now()
        generator.generate_to_csv()
        duration = datetime.now() - start_time
        print(f"\n✨ Data generation completed in {duration}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()