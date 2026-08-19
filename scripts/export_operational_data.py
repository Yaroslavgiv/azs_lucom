#!/usr/bin/env python3
"""Экспорт заявок и ТО из azs.db в assets/operational_data.json для мобильного приложения."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATIONS_JSON = ROOT / "assets" / "stations_yandex.json"
OUTPUT_JSON = ROOT / "assets" / "operational_data.json"


def load_station_numbers() -> list[str]:
    data = json.loads(STATIONS_JSON.read_text(encoding="utf-8"))
    return sorted({s["number"] for region in data.values() for s in region})


def export(source_db: Path) -> None:
    station_numbers = load_station_numbers()
    placeholders = ",".join("?" * len(station_numbers))

    conn = sqlite3.connect(source_db)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    requests = [
        dict(row)
        for row in cur.execute(
            f"""
            SELECT station_number, type, request_type, description,
                   date_created, status, close_comment, close_date
            FROM requests
            WHERE station_number IN ({placeholders})
            ORDER BY id
            """,
            station_numbers,
        )
    ]

    maintenance = [
        dict(row)
        for row in cur.execute(
            f"""
            SELECT station_number, month, status, date_done, to_type
            FROM maintenance
            WHERE station_number IN ({placeholders})
            ORDER BY month, station_number
            """,
            station_numbers,
        )
    ]
    conn.close()

    payload = {
        "station_numbers": station_numbers,
        "requests": requests,
        "maintenance": maintenance,
    }
    OUTPUT_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    open_count = sum(1 for r in requests if r.get("status") == "open")
    done_count = sum(1 for m in maintenance if m.get("status") == "done")
    print(f"Станций: {len(station_numbers)}")
    print(f"Заявок: {len(requests)} (открытых: {open_count})")
    print(f"ТО записей: {len(maintenance)} (выполнено: {done_count})")
    print(f"Записано: {OUTPUT_JSON}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source_db",
        help="Путь к azs.db",
        type=Path,
    )
    args = parser.parse_args()
    if not args.source_db.is_file():
        parser.error(f"База данных не найдена: {args.source_db}")
    export(args.source_db)


if __name__ == "__main__":
    main()
