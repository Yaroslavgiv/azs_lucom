#!/usr/bin/env python3
"""Geocode station addresses and update stations_yandex.json."""
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

STATIONS = [
    ("78129", "Штурманская", "Штурманская ул., 7, корп. 1"),
    ("78013", "Витебский", "Витебский просп., 17, корп. 2"),
    ("78172", "Ленинский", "Ленинский просп., 139, корп. 2"),
    ("78118", "Стачек", "просп. Стачек, 119"),
    ("78140", "Швецова", "Швецова, 31"),
    ("78072", "Бумажная", "Бумажная ул., 13"),
    ("78134", "Оборонная", "Оборонная ул., 30"),
    ("78141", "Глухоозёрское", "Глухоозёрское ш., 10"),
    ("78115", "Синопская", "Синопская наб., 12"),
    ("78126", "Шаумяна", "просп. Шаумяна, 15"),
    ("78117", "Комендантский", "Комендантский просп., 44, корп. 1"),
    ("78164", "Анисимовская", "Анисимовская дорога, 17"),
    ("78070", "Художников", "просп. Художников, 47"),
    ("78037", "Есенина", "ул. Есенина, 21"),
    ("78167", "Революции", "ш. Революции, 70"),
    ("78168", "Пискарёвский", "Пискарёвский просп., 46, корп. 1"),
    ("78120", "24-я линия", "24-я линия Васильевского острова, 21"),
    ("78136", "Средний Васильевского", "Средний просп. Васильевского острова, 74Б"),
    ("78179", "Арсенальная", "Арсенальная ул., Минеральная ул."),
]


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "azs-bot-mobile/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def geocode_nominatim(query: str):
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(
        {"q": query, "format": "json", "limit": 1, "countrycodes": "ru"}
    )
    data = fetch_json(url)
    if not data:
        return None
    return float(data[0]["lat"]), float(data[0]["lon"])


def geocode_photon(query: str):
    url = "https://photon.komoot.io/api/?" + urllib.parse.urlencode(
        {"q": query, "limit": 1, "lang": "ru"}
    )
    data = fetch_json(url)
    features = data.get("features") or []
    if not features:
        return None
    lon, lat = features[0]["geometry"]["coordinates"]
    return float(lat), float(lon)


def resolve_coords(number: str, address: str):
    queries = [
        f"Санкт-Петербург, {address}",
        f"Saint Petersburg, {address}",
        f"Лукойл {address}, Санкт-Петербург",
        f"АЗС Лукойл {number}, Санкт-Петербург",
    ]
    for q in queries:
        for fn in (geocode_nominatim, geocode_photon):
            try:
                coords = fn(q)
                if coords:
                    return coords, q, fn.__name__
            except Exception:
                pass
            time.sleep(0.3)
        time.sleep(0.8)
    return None, None, None


def main():
    spb = []
    for number, name, address in STATIONS:
        coords, query, source = resolve_coords(number, address)
        full_address = f"{address}, Санкт-Петербург"
        item = {
            "number": number,
            "name": name,
            "address": full_address,
            "region": "spb",
        }
        if coords:
            item["lat"] = round(coords[0], 7)
            item["lon"] = round(coords[1], 7)
            print(f"OK {number} {name}: {item['lat']}, {item['lon']} ({source})")
        else:
            item["lat"] = None
            item["lon"] = None
            print(f"FAIL {number} {name}")
        spb.append(item)

    json_path = Path(__file__).resolve().parent.parent / "assets" / "stations_yandex.json"
    data = json.loads(json_path.read_text(encoding="utf-8"))
    data["spb"] = spb
    json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {json_path}")


if __name__ == "__main__":
    main()
