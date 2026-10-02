import requests
import json

session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/",
})

session.get("https://www.nseindia.com", timeout=15)
url = "https://www.nseindia.com/api/corporates-corporateActions?index=equities&symbol=RELIANCE"
r = session.get(url, timeout=15)
data = r.json()
print("Sample subjects for RELIANCE:")
for item in data[:10]:
    print("ExDate:", item.get("exDate"), "RecDate:", item.get("recDate"), "Subject:", item.get("subject"))
