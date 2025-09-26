#!/usr/bin/env python3

import requests
import json

def test_connection():
    with open("config.json") as f:
        config = json.load(f)
    
    try:
        response = requests.get(
            f"{config['api_url']}/status",
            verify=False
        )
        print("✅ Connection successful!")
        print(f"📊 Server status: {response.json()}")
    except Exception as e:
        print(f"❌ Connection failed: {e}")

if __name__ == "__main__":
    test_connection()
