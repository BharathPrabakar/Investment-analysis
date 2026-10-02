import requests
import json

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": "https://www.bseindia.com/",
}

url = "https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w"
params = {
    "strCat": "D",
    "strPrevDate": "20240101",
    "strScrip": "",
    "strSearch": "S",
    "strToDate": "20241231",
    "strType": "C",
    "scripcode": "",
}

try:
    resp = requests.get(url, params=params, headers=headers, timeout=15)
    print("Status:", resp.status_code)
    print("Content-Type:", resp.headers.get("content-type"))
    print("Response text prefix:", resp.text[:300])
    try:
        data = resp.json()
        print("Parsed JSON count:", len(data) if isinstance(data, list) else len(data.get("Table", [])))
        sample = (data if isinstance(data, list) else data.get("Table", []))[:2]
        print("Sample:", json.dumps(sample, indent=2))
    except Exception as e:
        print("JSON parse error:", e)
except Exception as e:
    print("Request error:", e)
