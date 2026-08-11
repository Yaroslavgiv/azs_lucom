#!/usr/bin/env python3
import json
import re
import urllib.request
from pathlib import Path

NUMBERS = [
    "78129", "78013", "78172", "78118", "78140", "78072", "78134", "78141",
    "78115", "78126", "78117", "78164", "78070", "78037", "78167", "78168",
    "78120", "78136", "78179",
]


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8", "replace")


def parse_coords(text: str):
    m = re.search(r"N\s*([\d,]+)\s*,\s*E\s*([\d,]+)", text)
    if not m:
        return None
    lat = float(m.group(1).replace(",", "."))
    lon = float(m.group(2).replace(",", "."))
    return lat, lon


def main():
    html = fetch("https://auto.lukoil.ru/ru/ProductsAndServices/PetrolStations")
    Path(r"d:\azs_bot\mobile\lukoil_page.html").write_text(html, encoding="utf-8")

    # Try to find embedded JSON with station list
    for num in NUMBERS:
        idx = html.find(num)
        print(num, "in page" if idx >= 0 else "NOT in page")

    # Search station detail pages by number in page links
    ids = re.findall(r'PetrolStation\?id=(\d+)&type=gasStation', html)
    print("station link ids", len(set(ids)))

    results = {}
    for sid in sorted(set(ids)):
        try:
            page = fetch(
                f"https://auto.lukoil.ru/ru/ProductsAndServices/PetrolStation?id={sid}&type=gasStation"
            )
        except Exception as e:
            continue
        num_match = re.search(r"АЗС №(\d+)", page)
        if not num_match:
            continue
        num = num_match.group(1)
        if num not in NUMBERS:
            continue
        coords = parse_coords(page)
        addr_match = re.search(
            r"г\. Санкт-Петербург[^<]*?(?:пр-кт|ул\.|ш\.|наб\.|перекрёсток)[^<]+",
            page,
        )
        results[num] = {
            "id": sid,
            "coords": coords,
            "snippet": page[page.find(f"АЗС №{num}"): page.find(f"АЗС №{num}") + 300],
        }
        print(num, coords)

    out = Path(r"d:\azs_bot\mobile\lukoil_coords.json")
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print("saved", out, "count", len(results))


if __name__ == "__main__":
    main()
