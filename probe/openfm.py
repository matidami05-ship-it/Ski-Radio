import json, re, subprocess, urllib.request, urllib.parse, concurrent.futures as cf
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
def page(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "pl,en"})
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.read(3_000_000).decode("utf-8", "ignore"), r.geturl()
    except Exception as e:
        return "", url

STREAM_RE = re.compile(r'https?://[^\s"\'<>\\]+?(?:\.mp3|\.aac|\.m3u8|\.pls|\.m3u|\.ogg|/stream[^\s"\'<>\\]*|/live[^\s"\'<>\\]*|:\d{4}/[^\s"\'<>\\]*|/;)(?:\?[^\s"\'<>\\]*)?', re.I)
SKIP = re.compile(r'\.(?:js|css|png|jpg|svg|webp|gif|html?)(?:$|\?)|facebook|twitter|google|apple\.com|youtube|instagram|schema\.org|w3\.org', re.I)

def test(url):
    p = subprocess.run(["curl", "-sS", "-L", "--http0.9", "-m", "7", "-A", UA, "-o", "/dev/null",
                        "-w", "%{http_code}|%{content_type}|%{url_effective}", url],
                       capture_output=True, text=True)
    code, ctype, final = (p.stdout.split("|") + ["", "", ""])[:3]
    ok = code in ("200", "206") and re.search(r"audio|mpegurl|octet|ogg|aac|mpeg|x-scpls", ctype or "", re.I)
    if code == "200" and url.endswith(".m3u8"): ok = True
    return bool(ok), code, ctype

stations = {
  "Polskie Radio Chicago 1030 AM": ["https://onlineradiobox.com/us/wnvr/", "https://radiohear.com/station/polskie-radio-1030-chicago-us", "https://tuningaradio.com/en/stations/united-states/chicago/polskie-radio-1030-chicago/", "https://www.radiostar.club/radio/polskie-radio-1030-chicago", "https://radio.streamitter.com/station/polskie-radio-chicago-N44U7B", "https://polskieradio.us/", "https://www.polskieradio.com/"],
  "Polskie Radio Chicago 107.1 FM": ["https://tunein.com/radio/Polskie-Radio-Chicago-1071-s256306/", "https://radiohear.com/station/polskie-radio-1030-chicago-wnvr-us"],
  "Polski FM 92.7 Chicago": ["https://tuningaradio.com/en/stations/united-states/chicago/polski-fm-wcpy/", "https://radiohear.com/station/polski-fm-pl", "https://www.polskifm.com/", "https://polskifm.com/"],
  "Radio Wawa": ["https://radioandpodcast.com/radio/poland/radio-wawa", "https://streema.com/radios/Radio_WAWA", "https://www.radiowawa.pl/", "https://wawa.pl/"],
  "Muzo.fm": ["https://www.muzo.fm/", "https://muzo.fm/", "https://streema.com/radios/Radio_Muzo_FM"],
  "Polskastacja": ["https://www.polskastacja.pl/", "https://polskastacja.pl/"],
  "Radio Białystok": ["https://www.radio.bialystok.pl/", "https://onlineradiobox.com/pl/bialystok/"],
  "Radio dla Ciebie (RDC)": ["https://www.rdc.pl/", "https://onlineradiobox.com/pl/rdc/"],
  "Radio PiK (Pomorza i Kujaw)": ["https://www.radiopik.pl/", "https://onlineradiobox.com/pl/pik/"],
  "Polskie Radio Chopin": ["https://www.polskieradio.pl/", "https://www.polskieradio.pl/radio-chopin", "https://onlineradiobox.com/pl/polskieradiochopin/"],
  "RMF Dla Dzieci (kids)": ["https://radiohear.com/station/rmf-dla-dzieci-pl", "https://www.rmfon.pl/play,107"],
  "Polskie Radio Dzieciom (kids)": ["https://www.polskieradio.pl/dzieci", "https://onlineradiobox.com/pl/polskieradiodzieciom/"],
}
extra = {
  "Polskie Radio Chopin": [f"https://stream{n}.polskieradio.pl/{c}/{c}.sdp/playlist.m3u8" for n in (3, 11, 13, 85) for c in ("pr5", "chopin", "prchopin")],
}

def run(name):
    cands, notes = [], []
    for u in stations[name]:
        html, final = page(u)
        notes.append(f"{u} -> {len(html)}b")
        for m in STREAM_RE.findall(html.replace("\\/", "/")):
            m = m.rstrip(").,;'\"")
            if not SKIP.search(m) and m not in cands:
                cands.append(m)
    cands += [c for c in extra.get(name, []) if c not in cands]
    results = []
    for c in cands[:40]:
        ok, code, ct = test(c)
        results.append((ok, c, code, ct))
    return name, notes, results

with cf.ThreadPoolExecutor(6) as ex:
    for name, notes, results in ex.map(run, stations):
        good = [r for r in results if r[0]]
        print(f"\n=== {name}: {len(good)} working of {len(results)} candidates ===")
        for n in notes: print("   page:", n)
        for ok, c, code, ct in (good[:6] or results[:6]):
            print(f"   {'PLAYS ' if ok else 'no    '} {code} {ct[:28]:28} {c[:140]}")

print("\n=== Directory check for kids / Chopin / Dwójka ===")
API = "https://de1.api.radio-browser.info/json/stations/search?"
for q in ["dzieci", "Chopin", "Dwójka", "Program 2", "Bajka", "Wawa", "Muzo"]:
    d = json.loads(urllib.request.urlopen(urllib.request.Request(API + urllib.parse.urlencode({"name": q, "countrycode": "PL", "limit": 8, "order": "clickcount", "reverse": "true", "hidebroken": "true"}), headers={"User-Agent": "SkiRadio/1.0"}), timeout=20).read())
    print(f"  {q}: " + "; ".join(f"{s['name']} -> {test(s['url_resolved'])[0] and 'PLAYS' or 'no'}" for s in d[:5]) if d else f"  {q}: none")
