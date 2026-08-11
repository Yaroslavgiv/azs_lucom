#!/usr/bin/env python3
import json
import urllib.parse
import urllib.request

queries = [
    """
[out:json][timeout:60];
area["name"="Санкт-Петербург"]["boundary"="administrative"]->.spb;
(
  node["amenity"="fuel"](area.spb);
  way["amenity"="fuel"](area.spb);
);
out center tags;
""",
]

for query in queries:
    url = "https://overpass-api.de/api/interpreter"
    req = urllib.request.Request(
        url,
        data=urllib.parse.urlencode({"data": query}).encode(),
        method="POST",
        headers={"User-Agent": "azs-bot-mobile/1.0"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode())

    for el in data["elements"]:
        tags = el.get("tags", {})
        blob = " ".join(
            [
                tags.get("addr:street", ""),
                tags.get("addr:housenumber", ""),
                tags.get("name", ""),
            ]
        ).lower()
        if "24" in blob and ("лин" in blob or "lin" in blob):
            lat = el.get("lat") or el["center"]["lat"]
            lon = el.get("lon") or el["center"]["lon"]
            print(lat, lon, blob)
