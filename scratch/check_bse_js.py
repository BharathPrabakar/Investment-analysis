import urllib.request
import re

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
}

js_url = 'https://www.bseindia.com/assets/includenew/js/main-2V6Q7BOC.js'
try:
    req = urllib.request.Request(js_url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        content = resp.read().decode('utf-8', errors='ignore')
        matches = re.findall(r'https?://api\.bseindia\.com/[^"\'`\s\)]+', content)
        print("Found bse api URLs:", set(matches[:30]))
        # also search for CorporateAction
        corp_matches = re.findall(r'[^"\'`\s\)]*(?:Corp|Action|dividend)[^"\'`\s\)]*', content, re.IGNORECASE)
        print("Corp action related matches:", set([m for m in corp_matches if '/' in m][:30]))
except Exception as e:
    print("Error:", e)
