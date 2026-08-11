"""
One-shot upload of seed JSON assets into Firestore (project my-home-chat-915a3).

Requires:
  pip install firebase-admin
  GOOGLE_APPLICATION_CREDENTIALS pointing to a service account JSON
  OR run: firebase login && use application default credentials

Usage (from mobile/):
  python scripts/upload_seed_to_firestore.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("Install firebase-admin: pip install firebase-admin", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
PROJECT_ID = "my-home-chat-915a3"


def _init():
    if not firebase_admin._apps:
        try:
            firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
        except Exception:
            # Fallback: application default / service account via env
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})
    return firestore.client()


def upload_stations(db):
    path = ASSETS / "stations_yandex.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    stations = []
    if isinstance(data, list):
        stations = data
    elif isinstance(data, dict):
        if "stations" in data:
            stations = data["stations"]
        else:
            for region_key, items in data.items():
                if isinstance(items, list):
                    stations.extend(items)
    batch = db.batch()
    count = 0
    for s in stations:
        number = str(s.get("number") or s.get("id") or "").strip()
        if not number:
            continue
        ref = db.collection("stations").document(number)
        batch.set(
            ref,
            {
                "name": s.get("name") or "",
                "address": s.get("address") or "",
                "lat": s.get("lat"),
                "lon": s.get("lon"),
                "region": s.get("region") or "",
                "geocode_status": s.get("geocode_status") or (1 if s.get("lat") else 0),
            },
            merge=True,
        )
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    if count % 400 != 0:
        batch.commit()
    print(f"stations: {count}")


def upload_equipment(db):
    path = ASSETS / "station_equipment.json"
    raw = json.loads(path.read_text(encoding="utf-8"))
    items = raw if isinstance(raw, list) else raw.get("equipment", raw.get("items", []))
    batch = db.batch()
    count = 0
    for item in items:
        payload = {
            "station_number": str(item.get("station_number") or ""),
            "category": item.get("category") or "",
            "description": item.get("description") or "",
        }
        if not payload["station_number"]:
            continue
        ref = db.collection("station_equipment").document()
        batch.set(ref, payload)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"station_equipment: {count}")


def upload_operational(db):
    path = ASSETS / "operational_data.json"
    if not path.exists():
        print("operational_data.json missing, skip")
        return
    raw = json.loads(path.read_text(encoding="utf-8"))
    requests = raw.get("requests", []) if isinstance(raw, dict) else []
    maintenance = raw.get("maintenance", []) if isinstance(raw, dict) else []

    batch = db.batch()
    count = 0
    for r in requests:
        ref = db.collection("requests").document()
        batch.set(
            ref,
            {
                "station_number": str(r.get("station_number") or ""),
                "type": r.get("type") or "НЗ",
                "request_type": r.get("request_type") or "",
                "description": r.get("description") or "",
                "date_created": r.get("date_created") or "",
                "status": r.get("status") or "open",
                "close_comment": r.get("close_comment"),
                "close_date": r.get("close_date"),
            },
        )
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"requests: {count}")

    batch = db.batch()
    count = 0
    for m in maintenance:
        sn = str(m.get("station_number") or "")
        month = str(m.get("month") or "")
        if not sn or not month:
            continue
        doc_id = f"{sn}_{month}"
        ref = db.collection("maintenance").document(doc_id)
        batch.set(
            ref,
            {
                "station_number": sn,
                "month": month,
                "status": m.get("status") or "pending",
                "date_done": m.get("date_done"),
                "to_type": m.get("to_type"),
            },
            merge=True,
        )
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"maintenance: {count}")


def main():
    db = _init()
    existing = list(db.collection("stations").limit(1).stream())
    if existing:
        print("stations already present — abort (safe mode). Delete collection to re-seed.")
        return
    upload_stations(db)
    upload_equipment(db)
    upload_operational(db)
    print("Done.")


if __name__ == "__main__":
    main()
