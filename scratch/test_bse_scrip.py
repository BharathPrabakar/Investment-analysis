import requests
import json

session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
})

session.get("https://www.bseindia.com/corporates/corporate_act.aspx", timeout=15)

session.headers.update({
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.bseindia.com/corporates/corporate_act.aspx",
    "Origin": "https://www.bseindia.com",
})

# Let's try 500325 (Reliance) or strScrip / scripcode
url = "https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w"
params = {
    "strCat": "D",
    "strPrevDate": "20200101",
    "strScrip": "500325",
    "strSearch": "S",
    "strToDate": "20261231",
    "strType": "C",
    "scripcode": "500325",
}
r = session.get(url, params=params, timeout=15)
print("With 500325 status:", r.status_code)
print("Response text:", r.text[:500])
try:
    data = r.json()
    print("Parsed JSON keys/type:", type(data), len(data) if isinstance(data, list) else data.keys())
    if isinstance(data, dict) and "Table" in data:
        print("Table len:", len(data["Table"]))
        if data["Table"]:
            print("First item:", json.dumps(data["Table"][0], indent=2))
except Exception as e:
    print("JSON error:", e)
