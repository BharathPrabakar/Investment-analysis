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

url = "https://api.bseindia.com/BseIndiaAPI/api/CorporateAction/w"
params = {
    "strCat": "D",
    "strPrevDate": "20200101",
    "strScrip": "",
    "strSearch": "S",
    "strToDate": "20261231",
    "strType": "C",
    "scripcode": "500325",
}
r = session.get(url, params=params, timeout=15)
data = r.json()
print("Keys:", data.keys())
print("Table:", json.dumps(data.get("Table", [])[:3], indent=2))
