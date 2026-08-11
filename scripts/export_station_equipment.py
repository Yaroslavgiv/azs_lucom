#!/usr/bin/env python3
"""Экспорт оборудования из актов АПС/КТСБ в assets/station_equipment.json."""

from __future__ import annotations

import argparse
import json
import os
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
STATIONS_JSON = ROOT / "assets" / "stations_yandex.json"
OUTPUT_JSON = ROOT / "assets" / "station_equipment.json"
CATEGORY_FIRE = "Пожарка"
CATEGORY_KTSB = "КТСБ"
W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

DEFAULT_PATHS = {
    "spb_aps": Path(r"c:\Users\User\Downloads\С флешки\Aкты\ААЗС\АПС\2026"),
    "novgorod_aps_feb": Path(
        r"c:\Users\User\Downloads\С флешки\Aкты\Новгородские АЗС\2026\Февраль"
    ),
    "novgorod_aps_extra": Path(
        r"c:\Users\User\Downloads\С флешки\Aкты\Новгородские АЗС\АПС"
    ),
    "novgorod_ktsb": Path(
        r"c:\Users\User\Downloads\С флешки\Aкты\Новгородские АЗС\КТСБ"
    ),
}


def para_text(element: ET.Element) -> str:
    return "".join((node.text or "") for node in element.iter(f"{W}t"))


def load_station_numbers() -> dict[str, set[str]]:
    data = json.loads(STATIONS_JSON.read_text(encoding="utf-8"))
    return {
        "spb": {station["number"] for station in data["spb"]},
        "novgorod": {station["number"] for station in data["novgorod"]},
    }


def station_from_spb_filename(filename: str) -> str | None:
    match = re.search(r"(\d{2,3})\.docx$", filename, re.IGNORECASE)
    if not match:
        return None
    return "78" + match.group(1).zfill(3)


def station_from_novgorod_filename(filename: str) -> str | None:
    match = re.match(r"^(\d{5})\b", filename)
    return match.group(1) if match else None


def station_from_docx_text(path: Path) -> str | None:
    with zipfile.ZipFile(path) as archive:
        document = ET.fromstring(archive.read("word/document.xml"))
    text = para_text(document)
    match = re.search(r"АЗС\s*№?\s*(\d{5})", text)
    if match:
        return match.group(1)
    match = re.search(r"\b(\d{5})\b", text)
    return match.group(1) if match else None


def extract_aps_equipment(path: Path) -> list[str]:
    with zipfile.ZipFile(path) as archive:
        document = ET.fromstring(archive.read("word/document.xml"))

    tables = list(document.iter(f"{W}tbl"))
    if not tables:
        return []

    items: list[str] = []
    for row in list(tables[0].iter(f"{W}tr"))[1:]:
        cells = [para_text(cell).strip() for cell in row.iter(f"{W}tc")]
        if len(cells) < 2 or not cells[0]:
            continue
        name, qty = cells[0], cells[1]
        model = cells[2] if len(cells) > 2 else ""
        description = f"{name} — {qty}, {model}" if model else f"{name} — {qty}"
        items.append(description)
    return items


def split_equipment_lines(value: str) -> list[str]:
    lines: list[str] = []
    for chunk in re.split(r"[\r\n\x0b]+", value):
        line = chunk.strip()
        if line:
            lines.append(line)
    return lines


def extract_ktsb_equipment(path: Path) -> list[str]:
    try:
        import win32com.client  # type: ignore
    except ImportError as error:
        raise RuntimeError(
            "Для чтения .doc установите pywin32: pip install pywin32"
        ) from error

    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    items: list[str] = []
    document = None
    try:
        document = word.Documents.Open(str(path.resolve()))
        if document.Tables.Count < 1:
            return items

        table = document.Tables(1)
        for row_index in range(2, table.Rows.Count + 1):
            cells: list[str] = []
            for col_index in range(1, table.Columns.Count + 1):
                try:
                    value = (
                        table.Cell(row_index, col_index)
                        .Range.Text.replace("\r\x07", "")
                        .replace("\x07", "")
                        .strip()
                    )
                except Exception:
                    value = ""
                cells.append(value)

            if len(cells) < 3:
                continue

            equipment_cell = cells[2]
            if not equipment_cell:
                continue
            if equipment_cell.lower().startswith("количество"):
                continue

            first_cell = cells[0]
            if first_cell.upper().startswith("СИСТЕМА"):
                continue

            for line in split_equipment_lines(equipment_cell):
                items.append(line)
    finally:
        if document is not None:
            document.Close(False)
        word.Quit()

    return items


def collect_aps_from_folder(
    folder: Path,
    allowed: set[str],
    station_resolver,
) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    if not folder.is_dir():
        return result

    for path in sorted(folder.glob("*.docx")):
        if path.name.lower().startswith("офис"):
            continue
        station_number = station_resolver(path.name) or station_from_docx_text(path)
        if not station_number or station_number not in allowed:
            continue
        result[station_number] = extract_aps_equipment(path)
    return result


def merge_aps(
    primary: dict[str, list[str]],
    fallback: dict[str, list[str]],
    allowed: set[str],
) -> dict[str, list[str]]:
    merged = dict(primary)
    for station_number, items in fallback.items():
        if station_number in allowed and station_number not in merged:
            merged[station_number] = items
    return merged


def collect_ktsb(folder: Path, allowed: set[str]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    if not folder.is_dir():
        return result

    for path in sorted(folder.glob("*.doc")):
        station_number = station_from_novgorod_filename(path.name)
        if not station_number or station_number not in allowed:
            continue
        result[station_number] = extract_ktsb_equipment(path)
    return result


def export(paths: dict[str, Path]) -> None:
    regions = load_station_numbers()
    equipment: list[dict[str, str]] = []

    spb_aps = collect_aps_from_folder(
        paths["spb_aps"], regions["spb"], station_from_spb_filename
    )
    novgorod_aps = merge_aps(
        collect_aps_from_folder(
            paths["novgorod_aps_feb"],
            regions["novgorod"],
            station_from_novgorod_filename,
        ),
        collect_aps_from_folder(
            paths["novgorod_aps_extra"],
            regions["novgorod"],
            station_from_novgorod_filename,
        ),
        regions["novgorod"],
    )
    novgorod_ktsb = collect_ktsb(paths["novgorod_ktsb"], regions["novgorod"])

    for station_number, items in spb_aps.items():
        for description in items:
            equipment.append(
                {
                    "station_number": station_number,
                    "category": CATEGORY_FIRE,
                    "description": description,
                }
            )

    for station_number, items in novgorod_aps.items():
        for description in items:
            equipment.append(
                {
                    "station_number": station_number,
                    "category": CATEGORY_FIRE,
                    "description": description,
                }
            )

    for station_number, items in novgorod_ktsb.items():
        for description in items:
            equipment.append(
                {
                    "station_number": station_number,
                    "category": CATEGORY_KTSB,
                    "description": description,
                }
            )

    all_station_numbers = sorted(regions["spb"] | regions["novgorod"])
    payload = {
        "station_numbers": all_station_numbers,
        "equipment": equipment,
        "summary": {
            "spb_fire_stations": len(spb_aps),
            "novgorod_fire_stations": len(novgorod_aps),
            "novgorod_ktsb_stations": len(novgorod_ktsb),
            "total_items": len(equipment),
        },
    }
    OUTPUT_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"СПб Пожарка: {len(spb_aps)} станций")
    print(f"Новгород Пожарка: {len(novgorod_aps)} станций")
    missing_fire = sorted(regions["novgorod"] - set(novgorod_aps))
    if missing_fire:
        print(f"Новгород без актов АПС: {', '.join(missing_fire)}")
    print(f"Новгород КТСБ: {len(novgorod_ktsb)} станций")
    print(f"Всего записей: {len(equipment)}")
    print(f"Записано: {OUTPUT_JSON}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spb-aps", type=Path, default=DEFAULT_PATHS["spb_aps"])
    parser.add_argument(
        "--novgorod-aps-feb", type=Path, default=DEFAULT_PATHS["novgorod_aps_feb"]
    )
    parser.add_argument(
        "--novgorod-aps-extra", type=Path, default=DEFAULT_PATHS["novgorod_aps_extra"]
    )
    parser.add_argument("--novgorod-ktsb", type=Path, default=DEFAULT_PATHS["novgorod_ktsb"])
    args = parser.parse_args()
    export(
        {
            "spb_aps": args.spb_aps,
            "novgorod_aps_feb": args.novgorod_aps_feb,
            "novgorod_aps_extra": args.novgorod_aps_extra,
            "novgorod_ktsb": args.novgorod_ktsb,
        }
    )


if __name__ == "__main__":
    main()
