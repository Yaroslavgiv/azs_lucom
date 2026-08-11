#!/usr/bin/env python3
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

LUKOIL_OVERRIDES = {
    "78013": (59.87165, 30.35258),
}


def yandex_coords(query: str):
    url = (
        "https://yandex.tm/maps/?"
        + urllib.parse.urlencode({"text": f"Лукойл {query}, Санкт-Петербург"})
    )
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8", "replace")

    # Prefer org/house coordinates from state blob.
    matches = re.findall(r'"coordinates"\s*:\s*\[([0-9.]+),([0-9.]+)\]', html)
    if not matches:
        return None
    lon, lat = map(float, matches[0])
    return round(lat, 7), round(lon, 7)


def main():
    spb = []
    for number, name, address in STATIONS:
        coords = LUKOIL_OVERRIDES.get(number) or yandex_coords(address)
        item = {
            "number": number,
            "name": name,
            "address": f"{address}, Санкт-Петербург",
            "region": "spb",
        }
        if coords:
            item["lat"] = coords[0]
            item["lon"] = coords[1]
            print(f"OK {number} {name}: {coords}")
        else:
            item["lat"] = None
            item["lon"] = None
            print(f"FAIL {number} {name}")
        spb.append(item)
        time.sleep(0.8)

    json_path = Path(__file__).resolve().parent.parent / "assets" / "stations_yandex.json"
    data = json.loads(json_path.read_text(encoding="utf-8"))
    data["spb"] = spb
    json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
