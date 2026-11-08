import json, re, urllib.request, urllib.parse, ssl
UA = {"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"}
def get(url, n=None, timeout=20):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read(n) if n else r.read()
        return r.status, r.headers.get("Content-Type", ""), r.geturl(), body

print("=== 1. Radio Browser directory ===")
seen = {}
for q in ["open fm", "openfm", "open.fm"]:
    url = "https://de1.api.radio-browser.info/json/stations/search?" + urllib.parse.urlencode(
        {"name": q, "limit": 200, "order": "clickcount", "reverse": "true"})
    try:
        for s in json.loads(get(url)[3]):
            seen[s["stationuuid"]] = s
    except Exception as e:
        print("search failed", q, e)
rows = sorted(seen.values(), key=lambda s: -s["clickcount"])
ok = [s for s in rows if s["lastcheckok"] == 1]
print(f"{len(rows)} entries, {len(ok)} passing the directory's last check")
for s in rows[:80]:
    print(f"  [{'ok' if s['lastcheckok'] else 'BROKEN'}] {s['name'][:50]:50} | {s['countrycode']} | {s['url_resolved'][:80]}")

print("\n=== 2. open.fm website ===")
cands = set()
try:
    st, ct, final, body = get("https://open.fm/")
    html = body.decode("utf-8", "ignore")
    print("homepage", st, ct, final, len(html))
    scripts = set(re.findall(r'src="([^"]+\.js[^"]*)"', html))
    texts = [html]
    for s in list(scripts)[:25]:
        u = urllib.parse.urljoin(final, s)
        try:
            texts.append(get(u)[3].decode("utf-8", "ignore"))
        except Exception as e:
            print("  js fail", u, e)
    for t in texts:
        for m in re.findall(r'https?://[A-Za-z0-9.\-]*open\.fm[^"\'\s\\)]*', t):
            cands.add(m)
        for m in re.findall(r'["\'](/(?:api|radio)[^"\'\s]{2,120})["\']', t):
            cands.add("https://open.fm" + m)
    for c in sorted(cands)[:120]:
        print("  found:", c)
except Exception as e:
    print("homepage failed", e)

print("\n=== 3. Known/likely channel-list endpoints ===")
endpoints = [
    "https://open.fm/radio/api/v2/ofm/stations_slug.json",
    "https://open.fm/api/static/stations/stations_new.json",
    "https://open.fm/api/static/stations/stations.json",
    "https://open.fm/radio/api/v2/ofm/stations.json",
] + [c for c in cands if "station" in c.lower() and "{" not in c]
stream_urls = []
for e in dict.fromkeys(endpoints):
    try:
        st, ct, final, body = get(e)
        txt = body.decode("utf-8", "ignore")
        print(f"  {st} {ct[:30]} {e} ({len(txt)} bytes)")
        if "json" in ct or txt.lstrip()[:1] in "[{":
            data = json.loads(txt)
            print("    top-level:", type(data).__name__, list(data.keys())[:15] if isinstance(data, dict) else len(data))
            print("    sample:", json.dumps(data, ensure_ascii=False)[:1500])
            stream_urls += re.findall(r'https?://[^"\s]+?(?:\.m3u8|\.aac|\.mp3|/stream[^"\s]*|OFM[^"\s]*)', txt)
    except Exception as ex:
        print(f"  FAIL {e}: {ex}")

print("\n=== 4. Stream checks ===")
tests = list(dict.fromkeys(stream_urls))[:8] + [s["url_resolved"] for s in ok[:6]] + [
    "https://stream.open.fm/1", "http://stream.open.fm/1", "https://stream-cdn-1.open.fm/OFM1/ngrp:standard/playlist.m3u8"]
for u in dict.fromkeys(tests):
    try:
        st, ct, final, body = get(u, n=4096, timeout=15)
        head = body[:120]
        print(f"  {st} {ct[:35]:35} {u[:90]}  -> {final[:60]}  first bytes: {head[:60]!r}")
    except Exception as ex:
        print(f"  FAIL {u[:90]}: {ex}")
