import re, subprocess, urllib.request, urllib.parse, concurrent.futures as cf
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
def page(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=15) as r:
            return r.read(4_000_000).decode("utf-8", "ignore"), r.geturl()
    except Exception as e:
        return f"ERR {e}", url
def test(url):
    p = subprocess.run(["curl", "-sS", "-L", "--http0.9", "-m", "7", "-A", UA, "-o", "/tmp/b", "-w", "%{http_code}|%{content_type}", url], capture_output=True, text=True)
    code, ct = (p.stdout.split("|") + [""])[:2]
    head = open("/tmp/b", "rb").read(400) if code == "200" else b""
    ok = code == "200" and (re.search(r"audio|mpegurl|octet|ogg", ct, re.I) or b"#EXTM3U" in head)
    return ok, code, ct, head
def icy_title(url):
    p = subprocess.run(["curl", "-sS", "-L", "--http0.9", "-m", "6", "-H", "Icy-MetaData: 1", "-A", UA, "-D", "-", "-o", "/dev/null", url], capture_output=True, text=True)
    return " | ".join(l.strip() for l in p.stdout.splitlines() if l.lower().startswith(("icy-name", "icy-description", "icy-genre", "icy-url")))

KW = re.compile(r'(?:\.mp3|\.aac|\.m3u8|icecast|shoutcast|nadaje\.com|smcdn|reliastream|fastcast4u|streamtheworld|zeno\.fm|radiostream|/stream|:80\d\d|:90\d\d)', re.I)
def scan(name, url, follow_js=True):
    html, final = page(url)
    print(f"\n--- {name}: {url} ({len(html)} chars)")
    texts = [("page", html)]
    if follow_js:
        for s in list(dict.fromkeys(re.findall(r'<script[^>]+src="([^"]+)"', html)))[:30]:
            u = urllib.parse.urljoin(final, s)
            if any(x in u for x in ("google", "facebook", "gemius", "cookie", "gtag", "adservice")): continue
            texts.append((u.split("/")[-1][:40], page(u)[0]))
    found = []
    for src, t in texts:
        for m in KW.finditer(t):
            a, b = max(0, m.start() - 140), min(len(t), m.end() + 100)
            snip = re.sub(r"\s+", " ", t[a:b])
            urls = re.findall(r'https?:(?:\\?/){2}[^\s"\'<>]+', snip)
            for u in urls:
                u = u.replace("\\/", "/").rstrip("\\,;)")
                if KW.search(u) and not re.search(r"\.(js|css|png|jpg|svg|webp)(\?|$)", u) and u not in found:
                    found.append(u); print(f"   [{src}] {u[:150]}")
    return found

jobs = {
  "Polskie Radio Chicago": ["https://polskieradio.us/", "https://www.polskieradio.com/"],
  "Polski FM 92.7": ["https://www.polskifm.com/"],
  "Radio Wawa": ["https://www.radiowawa.pl/"],
  "Radio PiK": ["https://www.radiopik.pl/"],
  "Radio Białystok": ["https://www.radio.bialystok.pl/"],
  "RDC": ["https://www.rdc.pl/"],
  "Muzo.fm": ["https://www.muzo.fm/"],
  "Polskastacja": ["https://www.polskastacja.pl/", "http://www.polskastacja.pl/"],
}
for name, urls in jobs.items():
    cands = []
    for u in urls: cands += scan(name, u)
    for c in list(dict.fromkeys(cands))[:12]:
        ok, code, ct, head = test(c)
        print(f"   => {'PLAYS' if ok else 'no   '} {code} {ct[:25]:25} {c[:120]}  {icy_title(c)[:160] if ok else ''}")

print("\n=== Polskie Radio channel streams ===")
for n in ["1","2","3","4","5","6","7","8","9","10","24"]:
    for host in ("stream85", "stream3"):
        u = f"https://{host}.polskieradio.pl/pr{n}/pr{n}.sdp/playlist.m3u8"
        ok, code, ct, head = test(u)
        if ok: print(f"   PLAYS pr{n} {u}"); break
    else:
        print(f"   no    pr{n}")
html, _ = page("https://www.polskieradio.pl/")
for m in re.finditer(r'pr(\d+)\.sdp', html):
    print("   ctx:", re.sub(r"\s+", " ", html[max(0, m.start()-200):m.end()+40])[-260:])
    break
for m in re.finditer(r'(?i)chopin', html):
    s = re.sub(r"\s+", " ", html[max(0, m.start()-150):m.end()+150])
    if "sdp" in s or "stream" in s or "m3u8" in s: print("   chopin ctx:", s[:300])
