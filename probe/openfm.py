import subprocess
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
def info(url):
    p = subprocess.run(["curl", "-sS", "-L", "--http0.9", "-m", "8", "-H", "Icy-MetaData: 1", "-A", UA, "-D", "-", "-o", "/tmp/b", "-w", "HTTP %{http_code} %{content_type} %{size_download}B", url], capture_output=True, text=True)
    lines = [l.strip() for l in p.stdout.splitlines() if l.lower().startswith(("icy-name", "icy-description", "icy-url", "icy-br", "icy-genre")) or l.startswith("HTTP ")]
    raw = open("/tmp/b", "rb").read(200000)
    i = raw.find(b"StreamTitle=")
    title = raw[i:i+120].split(b";")[0].decode("utf-8", "ignore") if i >= 0 else ""
    return " | ".join(dict.fromkeys(lines)) + (f" | {title}" if title else "")
for name, url in [
    ("Polskie Radio Chicago (polskieradio.com)", "https://usa13.fastcast4u.com/proxy/andkog01?mp=/1"),
    ("reliastream 'polskieradio'", "https://s1.reliastream.com/proxy/polskieradio?mp=/stream"),
    ("Polski FM 92.7 candidate", "https://usa8.fastcast4u.com/proxy/live?mp=/1"),
    ("Radio Wawa candidate", "http://ic1.smcdn.pl:8000/1380-1.mp3"),
    ("Radio Wawa https", "https://ic1.smcdn.pl/1380-1.mp3"),
    ("Radio PiK", "https://stream4.nadaje.com:9005/"),
]:
    print(f"{name}:\n   {info(url)}")
