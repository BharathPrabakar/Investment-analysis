import urllib.request

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bseindia.com/corporates/corporate_act.aspx',
}

req = urllib.request.Request('https://www.bseindia.com/env.js', headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        print(resp.read().decode('utf-8'))
except Exception as e:
    print("env.js error:", e)
