#!/usr/bin/env python3
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

STATIONS = {
    "78129": ("Штурманская", ["штурманская", "7"]),
    "78013": ("Витебский", ["витебский", "17"]),
    "78172": ("Ленинский", ["ленинский", "139"]),
    "78118": ("Стачек", ["стачек", "119"]),
    "78140": ("Швецова", ["швецова", "31"]),
    "78072": ("Бумажная", ["бумажная", "13"]),
    "78134": ("Оборонная", ["оборонная", "30"]),
    "78141": ("Глухоозёрское", ["глухооз", "10"]),
    "78115": ("Синопская", ["синопск", "12"]),
    "78126": ("Шаумяна", ["шаумян", "15"]),
    "78117": ("Комендантский", ["комендант", "44"]),
    "78164": ("Анисимовская", ["анисимов", "17"]),
    "78070": ("Художников", ["художник", "47"]),
    "78037": ("Есенина", ["есенина", "21"]),
    "78167": ("Революции", ["революц", "70"]),
    "78168": ("Пискарёвский", ["пискар", "46"]),
    "78120": ("24-я линия", ["24", "21"]),
    "78136": ("Средний Васильевского", ["средний", "74"]),
    "78179": ("Арсенальная", ["арсенальн", "минеральн"]),
}

query = """
[out:json][timeout:120];
area["name"="Санкт-Петербург"]["boundary"="administrative"]->.spb;
(
  node["amenity"="fuel"](area.spb);
  way["amenity"="fuel"](area.spb);
);
out center tags;
"""

url = "https://overpass-api.de/api/interpreter"
req = urllib.request.Request(
    url,
    data=urllib.parse.urlencode({"data": query}).encode(),
    method="POST",
    headers={"User-Agent": "azs-bot-mobile/1.0"},
)
with urllib.request.urlopen(req, timeout=180) as resp:
    data = json.loads(resp.read().decode())

fuels = []
for el in data.get("elements", []):
    tags = el.get("tags", {})
    lat = el.get("lat") or el.get("center", {}).get("lat")
    lon = el.get("lon") or el.get("center", {}).get("lon")
    if lat is None:
        continue
    street = (tags.get("addr:street") or tags.get("addr:place") or "").lower()
    house = (tags.get("addr:housenumber") or "").lower()
    name = (tags.get("name") or "").lower()
    fuels.append(
        {
            "lat": lat,
            "lon": lon,
            "street": street,
            "house": house,
            "name": name,
            "tags": tags,
        }
    )

print("total fuel points", len(fuels))

matches = {}
for num, (title, keys) in STATIONS.items():
    best = None
    for f in fuels:
        blob = " ".join([f["street"], f["house"], f["name"]])
        if all(k in blob for k in keys):
            best = f
            break
    matches[num] = best
    if best:
        print(num, title, best["lat"], best["lon"], best["street"], best["house"])
    else:
        print(num, title, "NO MATCH")

Path(r"d:\azs_bot\mobile\overpass_matches.json").write_text(
    json.dumps(matches, ensure_ascii=False, indent=2, default=str),
    encoding="utf-8",
)
