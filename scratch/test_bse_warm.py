import requests
import json

session = requests.Session()
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
})

# Warm up
try:
    r1 = session.get("https://www.bseindia.com/corporates/corporate_act.aspx", timeout=15)
    print("Page status:", r1.status_code)
    print("Cookies:", session.cookies.get_dict())
    
    session.headers.update({
        "Accept": "application/json, text/plain, */*",
        "Referer": "https://www.bseindia.com/corporates/corporate_act.aspx",
        "Origin": "https://www.bseindia.com",
    })
    
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
    r2 = session.get(url, params=params, timeout=15)
    print("API status:", r2.status_code)
    print("API resp prefix:", r2.text[:200])
except Exception as e:
    print("Error:", e)
