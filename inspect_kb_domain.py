import lancedb
import pandas as pd
import json

# Connect to the database
db = lancedb.connect("/Users/puspa.kirana/Documents/GitHub/agentgip-paper1/database_lancedb")

# Open the kb_domain table
table = db.open_table("kb_domain")

# Fetch a sample row
sample = table.search().limit(5).to_pandas()

# Display column names
print("Column names:")
print(sample.columns.tolist())
print("\n" + "="*80 + "\n")

# Display first row data
if len(sample) > 0:
    print("First row data:")
    first_row = sample.iloc[0]
    for col in sample.columns:
        value = first_row[col]
        print(f"\n{col}:")
        print(f"  Type: {type(value)}")
        print(f"  Value: {value}")
        
        # If it's metadata_json, try to parse it
        if col == 'METADATA_JSON' and value:
            try:
                if isinstance(value, str):
                    metadata = json.loads(value)
                else:
                    metadata = value
                print(f"  Parsed metadata:")
                print(json.dumps(metadata, indent=4))
            except Exception as e:
                print(f"  Error parsing metadata: {e}")
