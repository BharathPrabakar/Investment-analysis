import requests
import json

session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/",
})

# Warm up
try:
    r0 = session.get("https://www.nseindia.com", timeout=15)
    print("NSE home:", r0.status_code)
    
    url = "https://www.nseindia.com/api/corporates-corporateActions"
    params = {
        "index": "equities",
        "symbol": "TCS",
    }
    r = session.get(url, params=params, timeout=15)
    print("NSE corporateActions status:", r.status_code)
    print("Text prefix:", r.text[:300])
    try:
        data = r.json()
        print("Data type/len:", type(data), len(data))
        if isinstance(data, list) and data:
            print("First item:", json.dumps(data[0], indent=2))
        elif isinstance(data, dict):
            print("Dict keys:", data.keys())
    except Exception as e:
        print("JSON err:", e)
except Exception as e:
    print("Error:", e)
