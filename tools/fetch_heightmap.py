#!/usr/bin/env python3
"""Gerçek yükseklik verisinden (SRTM tabanlı açık arazi karoları) harita bölgesi üretir.

Kullanım:
    python3 tools/fetch_heightmap.py gelibolu 39.95 26.12 40.36 26.48 [--zoom 12]

Çıktı:
    assets/maps/<ad>_height.png   Terrarium kodlu yükseklik (R*256 + G + B/256 - 32768 metre)
    data/maps/<ad>.json           Sınırlar (enlem/boylam), piksel boyutu
Kaynak: Mapzen/AWS Terrain Tiles (SRTM, GMTED, ETOPO1 vb.; https://registry.opendata.aws/terrain-tiles/)
"""
import argparse
import io
import json
import math
import os
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"


def tile_xy(lat, lon, z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("lat0", type=float)
    ap.add_argument("lon0", type=float)
    ap.add_argument("lat1", type=float)
    ap.add_argument("lon1", type=float)
    ap.add_argument("--zoom", type=int, default=12)
    a = ap.parse_args()
    z = a.zoom
    x0, y0 = tile_xy(a.lat1, a.lon0, z)  # kuzeybatı
    x1, y1 = tile_xy(a.lat0, a.lon1, z)  # güneydoğu
    tx0, ty0, tx1, ty1 = int(x0), int(y0), int(x1), int(y1)
    mosaic = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            req = urllib.request.Request(URL.format(z=z, x=tx, y=ty), headers={"User-Agent": "TurkHarp/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                tile = Image.open(io.BytesIO(r.read())).convert("RGB")
            mosaic.paste(tile, ((tx - tx0) * 256, (ty - ty0) * 256))
    # Web Mercator karolarından istenen kutuyu kes; sonra enlem/boylamda eşit aralıklı ızgaraya örnekle.
    left, top = (x0 - tx0) * 256, (y0 - ty0) * 256
    right, bottom = (x1 - tx0) * 256, (y1 - ty0) * 256
    lat_mid = math.radians((a.lat0 + a.lat1) / 2)
    m_per_px = 40075016.686 * math.cos(lat_mid) / (256 * 2 ** z)
    w_m = (a.lon1 - a.lon0) * 111320.0 * math.cos(lat_mid)
    h_m = (a.lat1 - a.lat0) * 110540.0
    w, h = int(w_m / m_per_px), int(h_m / m_per_px)
    src = mosaic.load()
    out = Image.new("RGB", (w, h))
    dst = out.load()
    for j in range(h):
        lat = a.lat1 - (a.lat1 - a.lat0) * (j + 0.5) / h
        _, py = tile_xy(lat, a.lon0, z)
        sy = min(max((py - ty0) * 256, 0), mosaic.height - 1)
        for i in range(w):
            lon = a.lon0 + (a.lon1 - a.lon0) * (i + 0.5) / w
            px, _ = tile_xy(lat, lon, z)
            sx = min(max((px - tx0) * 256, 0), mosaic.width - 1)
            dst[i, j] = src[int(sx), int(sy)]
    os.makedirs(os.path.join(ROOT, "assets/maps"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "data/maps"), exist_ok=True)
    out.save(os.path.join(ROOT, f"assets/maps/{a.name}_height.png"))
    meta = {"name": a.name, "lat0": a.lat0, "lon0": a.lon0, "lat1": a.lat1, "lon1": a.lon1,
            "width": w, "height": h, "width_m": round(w_m, 1), "height_m": round(h_m, 1),
            "source": "AWS Terrain Tiles (Mapzen), SRTM tabanlı, zoom %d" % z}
    with open(os.path.join(ROOT, f"data/maps/{a.name}.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    print(f"{w}x{h} piksel, {w_m/1000:.1f} x {h_m/1000:.1f} km")


if __name__ == "__main__":
    main()
