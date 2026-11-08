import json, urllib.request
def get(url, headers=None, n=600):
    h = {"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"}
    h.update(headers or {})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=15) as r:
            return r.status, dict(r.headers), r.read(n)
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read(n)
    except Exception as e:
        return "ERR", {}, str(e).encode()

print("=== runner location ===")
print(get("https://ipinfo.io/json")[2].decode()[:300])

print("\n=== channel list ===")
st = json.loads(get("https://open.fm/api/radio/stations", n=None)[2])
ch = list(st.values())
print(len(ch), "channels;", sum(c.get("premium") for c in ch), "premium;",
      "types:", sorted({c.get("contentType") for c in ch}))
print("examples:", [c["name"] for c in ch[:25]])

print("\n=== stream with different headers ===")
url = "https://stream-cdn-1.open.fm/OFM1/ngrp:standard/playlist.m3u8"
for label, hdr in [
    ("plain", {}),
    ("open.fm referer+origin", {"Referer": "https://open.fm/", "Origin": "https://open.fm"}),
    ("Polish IP header (X-Forwarded-For)", {"X-Forwarded-For": "83.0.0.1"}),
]:
    code, headers, body = get(url, hdr)
    print(f"  {label}: {code} server={headers.get('Server')} body={body[:200]!r}")

print("\n=== other stream hosts ===")
for u in ["https://stream-cdn-2.open.fm/OFM1/ngrp:standard/playlist.m3u8",
          "https://stream.open.fm/1",
          "https://open.fm/api/radio/playlist"]:
    code, headers, body = get(u, {"Referer": "https://open.fm/"})
    print(f"  {u}: {code} {headers.get('Content-Type')} {body[:200]!r}")
