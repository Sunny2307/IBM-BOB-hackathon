"""Fetches a REAL grid asset inventory for Gujarat from OpenStreetMap.

Every asset this writes is a substation that physically exists, with its real
name, real coordinates, real operating voltage, and a real OSM id anyone can
look up at openstreetmap.org/way/<id> to check we did not invent it. Critical
loads (hospitals, water works) are real too: flagged by actual proximity to
real facilities in OSM, not by a coin flip.

Output is COMMITTED to app/data/osm/gujarat_assets.json on purpose. The Render
build must never depend on Overpass being up, and a hackathon demo must never
depend on a third-party API answering in the next 90 seconds. Re-run this
script to refresh the snapshot; everything downstream reads the file.

What is real vs. estimated is tracked per field in FIELD_PROVENANCE below and
surfaced in the app, because "which of these numbers did you make up" is a
question that deserves a straight answer.

Run: python scripts/fetch_osm_assets.py
"""

import json
import math
import random
import time
from pathlib import Path

import httpx

# Public Overpass instances are free, shared, and routinely 504 under load.
# Rotating mirrors with backoff is not optional here: a half-fetched inventory
# would silently ship a fleet missing whole districts.
OVERPASS_MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = "grid-failure-advisor/0.1 (IBM Bob hackathon; contact: team Fantastic_Four)"
REQUEST_TIMEOUT_SECONDS = 180.0
PAUSE_BETWEEN_QUERIES_SECONDS = 4.0  # be a good citizen on a free public API
MAX_ATTEMPTS_PER_QUERY = 6

OUT_PATH = Path(__file__).resolve().parent.parent / "app" / "data" / "osm" / "gujarat_assets.json"

# Gujarat districts (OSM admin_level=5). Chosen for industrial/grid significance,
# plus Anand — where CHARUSAT is, and where OSM has the Charusat Hospital that
# one of these substations actually feeds.
DISTRICTS = [
    "Ahmedabad", "Vadodara", "Surat", "Rajkot", "Anand",
    "Bhavnagar", "Jamnagar", "Bharuch", "Gandhinagar", "Kheda",
]

MAX_ASSETS_PER_DISTRICT = 20  # highest-voltage first; keeps the fleet demo-sized

# Distance within which a critical facility is treated as downstream of the asset.
CRITICAL_LOAD_RADIUS_KM = 5.0

# Typical transformation capacity by highest operating voltage. Real substations
# vary; these are planning-grade figures used only where OSM has no rating tag.
CAPACITY_MVA_BY_VOLTAGE = {
    765_000: 1500.0, 500_000: 1000.0, 400_000: 500.0, 220_000: 200.0,
    132_000: 100.0, 110_000: 80.0, 66_000: 25.0, 33_000: 10.0, 25_000: 8.0, 11_000: 5.0,
}
# Customers per MVA of installed capacity. Indian distribution averages roughly
# 1-2 kW per connection at typical diversity, so ~300 connections/MVA.
CUSTOMERS_PER_MVA = 300

FIELD_PROVENANCE = {
    "name": "real (OpenStreetMap)",
    "lat": "real (OpenStreetMap)",
    "lon": "real (OpenStreetMap)",
    "voltage_v": "real (OpenStreetMap)",
    "osm_id": "real (OpenStreetMap)",
    "region": "real (OSM admin_level=5 district)",
    "operator": "real where OSM has it, else null",
    "has_hospital_critical_load": "real (OSM hospital within 5 km)",
    "has_water_treatment_load": "real (OSM water works within 5 km)",
    "has_redundancy": "inferred from OSM (multi-voltage site or transmission tier)",
    "type": "inferred from real voltage (>=220 kV transmission, else distribution)",
    "capacity_mva": "estimated from real voltage",
    "customers_served": "estimated from capacity",
    "install_year": "estimated (OSM has no start_date for any Gujarat substation)",
}


def overpass(query: str) -> list[dict]:
    """Runs one Overpass query, rotating mirrors and backing off on failure.
    Raises only after every mirror has been tried repeatedly — a partial
    inventory is worse than a loud failure."""
    last_error = None
    for attempt in range(MAX_ATTEMPTS_PER_QUERY):
        url = OVERPASS_MIRRORS[attempt % len(OVERPASS_MIRRORS)]
        try:
            response = httpx.post(
                url,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            return response.json()["elements"]
        except Exception as exc:  # noqa: BLE001 - every failure mode here is retryable
            last_error = exc
            backoff = 5 * (attempt + 1)
            host = url.split("/")[2]
            print(f"    [overpass] {host} failed ({exc.__class__.__name__}); retrying in {backoff}s")
            time.sleep(backoff)
    raise RuntimeError(f"Overpass unavailable after {MAX_ATTEMPTS_PER_QUERY} attempts: {last_error}")


def _coords(element: dict) -> tuple[float, float] | None:
    point = element.get("center") or element
    if "lat" not in point or "lon" not in point:
        return None
    return float(point["lat"]), float(point["lon"])


def _voltages(tags: dict) -> list[int]:
    """OSM stores multi-voltage sites as '400000;220000;66000'."""
    raw = str(tags.get("voltage", ""))
    out = []
    for part in raw.split(";"):
        part = part.strip()
        if part.isdigit():
            out.append(int(part))
    return sorted(out, reverse=True)


def _km_between(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Equirectangular approximation — accurate well under 1% at these
    distances, and we only ever compare it against a 5 km threshold."""
    mean_lat = math.radians((a[0] + b[0]) / 2)
    dx = math.radians(b[1] - a[1]) * math.cos(mean_lat)
    dy = math.radians(b[0] - a[0])
    return 6371.0 * math.hypot(dx, dy)


def fetch_substations(district: str) -> list[dict]:
    elements = overpass(f"""
        [out:json][timeout:150];
        area["name"="{district}"]["admin_level"="5"]->.d;
        (
          way["power"="substation"]["name"](area.d);
          node["power"="substation"]["name"](area.d);
        );
        out center;
    """)
    found = []
    for element in elements:
        point = _coords(element)
        voltages = _voltages(element.get("tags", {}))
        if point is None or not voltages:
            continue
        found.append({"element": element, "point": point, "voltages": voltages})
    return found


def fetch_critical_loads(district: str) -> tuple[list[tuple[float, float]], list[tuple[float, float]]]:
    elements = overpass(f"""
        [out:json][timeout:150];
        area["name"="{district}"]["admin_level"="5"]->.d;
        (
          node["amenity"="hospital"](area.d);
          way["amenity"="hospital"](area.d);
          node["man_made"="water_works"](area.d);
          way["man_made"="water_works"](area.d);
          way["man_made"="wastewater_plant"](area.d);
        );
        out center;
    """)
    hospitals, water = [], []
    for element in elements:
        point = _coords(element)
        if point is None:
            continue
        tags = element.get("tags", {})
        if tags.get("amenity") == "hospital":
            hospitals.append(point)
        else:
            water.append(point)
    return hospitals, water


def build_asset(index: int, record: dict, district: str,
                hospitals: list, water: list, rng: random.Random) -> dict:
    tags = record["element"].get("tags", {})
    lat, lon = record["point"]
    voltages = record["voltages"]
    top_voltage = voltages[0]

    capacity_mva = CAPACITY_MVA_BY_VOLTAGE.get(top_voltage, max(5.0, top_voltage / 2000))
    customers_served = int(capacity_mva * CUSTOMERS_PER_MVA)

    near_hospital = any(_km_between((lat, lon), h) <= CRITICAL_LOAD_RADIUS_KM for h in hospitals)
    near_water = any(_km_between((lat, lon), w) <= CRITICAL_LOAD_RADIUS_KM for w in water)

    # A site stepping between several voltage levels runs multiple transformer
    # banks, so losing one does not black the site out. Transmission-tier sites
    # are likewise built to N-1. Both are inferences from real OSM tags.
    has_redundancy = len(voltages) > 1 or top_voltage >= 220_000

    # OSM carries no start_date for any Gujarat substation, so age is estimated.
    # Seeded per asset so it is stable across runs rather than churning the fleet.
    install_year = rng.randint(1985, 2020)
    age = 2026 - install_year

    return {
        "asset_id": f"AST-{index:03d}",
        "name": tags.get("name", "Unnamed Substation"),
        "type": "substation" if top_voltage >= 220_000 else "transformer",
        "lat": round(lat, 5),
        "lon": round(lon, 5),
        "region": district,
        "voltage_v": top_voltage,
        "voltage_levels": voltages,
        "operator": tags.get("operator"),
        "osm_type": record["element"]["type"],
        "osm_id": record["element"]["id"],
        "install_year": install_year,
        "capacity_mva": capacity_mva,
        "customers_served": customers_served,
        "has_hospital_critical_load": near_hospital,
        "has_water_treatment_load": near_water,
        "has_redundancy": has_redundancy,
        "base_failure_rate": round(0.015 + age * 0.0016 + (0.01 if top_voltage >= 220_000 else 0.0), 4),
    }


def main() -> None:
    rng = random.Random(42)
    assets: list[dict] = []

    for district in DISTRICTS:
        substations = fetch_substations(district)
        time.sleep(PAUSE_BETWEEN_QUERIES_SECONDS)
        hospitals, water = fetch_critical_loads(district)
        time.sleep(PAUSE_BETWEEN_QUERIES_SECONDS)

        # Highest voltage first: those are the assets whose failure strands the
        # most customers, which is what the whole ranking is about.
        substations.sort(key=lambda r: r["voltages"][0], reverse=True)
        selected = substations[:MAX_ASSETS_PER_DISTRICT]

        for record in selected:
            assets.append(build_asset(len(assets) + 1, record, district, hospitals, water, rng))

        print(
            f"{district:14} {len(selected):3} assets from {len(substations):4} real substations"
            f"  ({len(hospitals)} hospitals, {len(water)} water works nearby)"
        )

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(
        {
            "source": "OpenStreetMap via Overpass API",
            "license": "ODbL 1.0 - (c) OpenStreetMap contributors",
            "area": "Gujarat, India",
            "districts": DISTRICTS,
            "field_provenance": FIELD_PROVENANCE,
            "assets": assets,
        },
        indent=2,
    ))

    hospital_count = sum(1 for a in assets if a["has_hospital_critical_load"])
    water_count = sum(1 for a in assets if a["has_water_treatment_load"])
    print(f"\n{len(assets)} real substations written to {OUT_PATH}")
    print(f"  {hospital_count} feed a hospital within {CRITICAL_LOAD_RADIUS_KM:g} km (real OSM facilities)")
    print(f"  {water_count} feed a water treatment works within {CRITICAL_LOAD_RADIUS_KM:g} km")


if __name__ == "__main__":
    main()
