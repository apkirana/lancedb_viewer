import requests
import json
import logging

logging.basicConfig(level=logging.INFO)

API_URL = "http://localhost:8001"
# Test table parameters
TABLE_NAME = "test_general_table"
TEST_DATA_1 = [{"id": "1", "name": "Alice", "age": 30}, {"id": "2", "name": "Bob", "age": 25}]
TEST_DATA_2 = [{"id": "1", "name": "Alice Updated", "age": 31}]

def test_api():
    # 1. Connect
    print("\n--- Connecting ---")
    res = requests.post(f"{API_URL}/api/connect/", json={
        "provider": "local",
        "local_path": "./test_lancedb" # Create a dummy db
    })
    print(res.json())

    # 2. Add Data
    print("\n--- Adding Data ---")
    res = requests.post(f"{API_URL}/api/add-data/", json={
        "table": TABLE_NAME,
        "data": TEST_DATA_1,
        "unique_field": "id"
    })
    print(res.json())

    # 3. Fetch Data
    print("\n--- Fetching Data ---")
    res = requests.get(f"{API_URL}/api/fetch-data/{TABLE_NAME}/")
    print(res.json())

    # 4. Update Data
    print("\n--- Updating Data ---")
    res = requests.post(f"{API_URL}/api/update-data/", json={
        "table": TABLE_NAME,
        "unique_field": "id",
        "data": TEST_DATA_2
    })
    print(res.json())

    # 5. Fetch Data Again (verify update)
    print("\n--- Fetching Data After Update ---")
    res = requests.get(f"{API_URL}/api/fetch-data/{TABLE_NAME}/")
    print(res.json())

    # 6. Delete Data
    print("\n--- Deleting Data ---")
    res = requests.post(f"{API_URL}/api/delete-data/", json={
        "table": TABLE_NAME,
        "condition": "id = '2'"
    })
    print(res.json())

    # 7. Fetch Data Again (verify delete)
    print("\n--- Fetching Data After Delete ---")
    res = requests.get(f"{API_URL}/api/fetch-data/{TABLE_NAME}/")
    print(res.json())

if __name__ == "__main__":
    try:
        test_api()
    except Exception as e:
        print(f"Error: {e}")
        print("Please ensure the backend is running (`python src/main.py` inside the backend dir).")
