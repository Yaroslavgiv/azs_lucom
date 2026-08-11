#!/usr/bin/env python3
"""Build stations_yandex.json from docx data with geocoded coordinates."""
import json
import re
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
    ("78179", "Арсенальная", "перекрёсток Арсенальная улица - Минеральная"),
]

PHOTON_QUERIES = {
    "78129": "Штурманская 7к1, Санкт-Петербург",
    "78013": "Витебский проспект 17к2, Санкт-Петербург",
    "78172": "Ленинский проспект 139к2, Санкт-Петербург",
    "78118": "проспект Стачек 119, Санкт-Петербург",
    "78140": "улица Швецова 31, Санкт-Петербург",
    "78072": "улица Бумажная 13, Санкт-Петербург",
    "78134": "улица Оборонная 30, Санкт-Петербург",
    "78141": "Глухоозёрское шоссе 10, Санкт-Петербург",
    "78115": "Синопская набережная 12, Санкт-Петербург",
    "78126": "проспект Шаумяна 15, Санкт-Петербург",
    "78117": "Комендантский проспект 44к1, Санкт-Петербург",
    "78164": "Анисимовская дорога 17, Санкт-Петербург",
    "78070": "проспект Художников 47, Санкт-Петербург",
    "78037": "улица Есенина 21, Санкт-Петербург",
    "78167": "шоссе Революции 70, Санкт-Петербург",
    "78168": "Пискарёвский проспект 46к1, Санкт-Петербург",
    "78120": "24-я линия Васильевского острова 21, Санкт-Петербург",
    "78136": "Средний проспект Васильевского острова 74Б, Санкт-Петербург",
    "78179": "Арсенальная улица Минеральная улица, Санкт-Петербург",
}

# Lukoil internal page IDs discovered via official site.
LUKOIL_IDS = {
    "78013": "1919",
}


def geocode_photon(query: str):
    url = "https://photon.komoot.io/api/?" + urllib.parse.urlencode(
        {"q": query, "limit": 1}
    )
    req = urllib.request.Request(url, headers={"User-Agent": "azs-bot-mobile/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode())
    features = data.get("features") or []
    if not features:
        return None
    lon, lat = features[0]["geometry"]["coordinates"]
    return round(lat, 7), round(lon, 7)


def fetch_lukoil_coords(station_id: str):
    url = (
        "https://auto.lukoil.ru/ru/ProductsAndServices/PetrolStation"
        f"?id={station_id}&type=gasStation"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        page = resp.read().decode("utf-8", "replace")
    m = re.search(r"N\s*([\d,]+)\s*,\s*E\s*([\d,]+)", page)
    if not m:
        return None
    return (
        round(float(m.group(1).replace(",", ".")), 7),
        round(float(m.group(2).replace(",", ".")), 7),
    )


def resolve_coords(number: str):
    if number in LUKOIL_IDS:
        coords = fetch_lukoil_coords(LUKOIL_IDS[number])
        if coords:
            return coords, "lukoil"

    query = PHOTON_QUERIES[number]
    try:
        coords = geocode_photon(query)
        if coords:
            return coords, "photon"
    except Exception as exc:
        print(f"  photon error for {number}: {exc}")

    return None, None


def main():
    spb = []
    for number, name, address in STATIONS:
        coords, source = resolve_coords(number)
        full_address = f"{address}, Санкт-Петербург"
        item = {
            "number": number,
            "name": name,
            "address": full_address,
            "region": "spb",
        }
        if coords:
            item["lat"] = coords[0]
            item["lon"] = coords[1]
            print(f"OK {number} {name}: {coords} ({source})")
        else:
            item["lat"] = None
            item["lon"] = None
            print(f"FAIL {number} {name}")
        spb.append(item)
        time.sleep(0.5)

    json_path = Path(__file__).resolve().parent.parent / "assets" / "stations_yandex.json"
    data = json.loads(json_path.read_text(encoding="utf-8"))
    data["spb"] = spb
    json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Updated", json_path)


if __name__ == "__main__":
    main()
