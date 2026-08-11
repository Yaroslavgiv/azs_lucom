#!/usr/bin/env python3
import json
import re
import sys
import urllib.parse
import urllib.request


def fetch_coords(query: str):
    url = (
        "https://yandex.tm/maps/?"
        + urllib.parse.urlencode({"text": query, "ll": "30.3,59.95", "z": "11"})
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8", "replace")

    m = re.search(r'"coordinates"\s*:\s*\[([0-9.]+),([0-9.]+)\]', html)
    if not m:
        return None
    lon = float(m.group(1))
    lat = float(m.group(2))
    return lat, lon


if __name__ == "__main__":
    query = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Лукойл Пискарёвский проспект 46 Санкт-Петербург"
    coords = fetch_coords(query)
    print(json.dumps({"query": query, "coords": coords}, ensure_ascii=False))
