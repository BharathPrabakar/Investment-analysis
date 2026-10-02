import urllib.request
import re
import json

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bseindia.com/',
    'Accept': '*/*',
}

req = urllib.request.Request('https://www.bseindia.com/corporates/corporate_act.aspx', headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        html = resp.read().decode('utf-8', errors='ignore')
        with open('bse_page.html', 'w', encoding='utf-8') as f:
            f.write(html)
        print("Wrote bse_page.html, size:", len(html))
        # Find script tags
        for src in re.findall(r'src=["\']([^"\']+)["\']', html):
            print("Script:", src)
except Exception as e:
    print("Error:", e)
