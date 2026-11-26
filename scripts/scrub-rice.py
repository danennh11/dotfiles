#!/usr/bin/env python3
"""Strip personal data from an exported Ryoku rice before it goes into a public repo.

Removes the IP-geolocation cache (IP address, network, city, coordinates) and
clears the weather city. Run on a rice folder: scrub-rice.py rice/nend
Called automatically by ./dot rice.
"""
import json
import pathlib
import sys

# Keys whose values identify where the machine is or who runs it.
GEO_KEYS = {"ip", "asn", "org", "city", "region", "region_code", "postal",
            "latitude", "longitude", "lat", "lon", "lng", "country_code",
            "country_name", "timezone", "network"}


def scrub(node, path=""):
    changed = 0
    if isinstance(node, dict):
        for key in list(node):
            val = node[key]
            # A "location" object that carries an IP is an IP-geolocation cache: drop it whole.
            if key == "location" and isinstance(val, dict) and ("ip" in val or "latitude" in val):
                node[key] = {}
                changed += 1
            elif key in ("city", "latitude", "longitude") and val not in ("", None, 0):
                node[key] = "" if key == "city" else 0
                changed += 1
            else:
                changed += scrub(val, f"{path}.{key}")
    elif isinstance(node, list):
        for item in node:
            changed += scrub(item, path)
    return changed


def main(folder):
    total = 0
    for f in sorted(pathlib.Path(folder).rglob("*.json")):
        try:
            data = json.loads(f.read_text())
        except ValueError:
            print(f"  skip (not plain JSON): {f}")
            continue
        n = scrub(data)
        if n:
            f.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
            print(f"  scrubbed {n} field(s): {f}")
            total += n
    leftovers = [k for f in pathlib.Path(folder).rglob("*.json")
                 for k in GEO_KEYS if f'"{k}": "' in f.read_text() and k in ("ip", "asn", "org")]
    if leftovers:
        sys.exit(f"  still found: {sorted(set(leftovers))}")
    print(f"  done, {total} field(s) cleared")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "rice/nend")
