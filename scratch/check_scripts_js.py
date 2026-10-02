import urllib.request
import re

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
}

js_url = 'https://www.bseindia.com/assets/includenew/js/scripts-DS3I3X7Y.js'
try:
    req = urllib.request.Request(js_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        content = resp.read().decode('utf-8', errors='ignore')
        matches = re.findall(r'https?://[^"\'`\s\)]+', content)
        print("Found URLs in scripts.js:", set(matches[:30]))
except Exception as e:
    print("scripts.js error:", e)
