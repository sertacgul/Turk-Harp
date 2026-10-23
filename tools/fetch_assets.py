#!/usr/bin/env python3
"""Poly Haven'dan (CC0) gerçekçi gökyüzü, doku ve modelleri indirir.

Kullanım:
    python3 tools/fetch_assets.py            # eksikleri indirir
    python3 tools/fetch_assets.py --list     # yalnızca seçimleri gösterir
    python3 tools/fetch_assets.py --res 1k   # daha küçük dosyalar (varsayılan 2k)

Varlıklar katalogdan etiketlerine göre seçilir; tercih edilen kimlikler varsa onlar alınır.
İndirilenler:
    assets/hdri/day.hdr, dawn.hdr, night.hdr
    assets/textures/<katman>_albedo.jpg, _normal.jpg   (grass, dirt, rock, sand)
    assets/models/rock_*.gltf, bush_*.gltf (+ .bin ve dokular)
    assets/CREDITS.md   (hangi varlığın nereden geldiği)
Poly Haven varlıkları CC0'dır: atıf gerekmez ama CREDITS.md'de kaynak belirtilir.
"""
import argparse
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.polyhaven.com"
UA = {"User-Agent": "TurkHarp-asset-fetcher/1.0 (https://github.com/sertacgul/Turk-Harp)"}

# Gökyüzleri yalnızca "pure skies" (ufukta dağ/bina olmayan) HDRI'lardan seçilir: kendi arazimizle çakışmasın.
# katman -> (tercih edilen kimlikler, aranacak etiketler)
HDRIS = {
    "day": (["kloofendal_48d_partly_cloudy_puresky", "kloofendal_43d_clear_puresky"], ["partly cloudy", "clear", "midday", "sunny"]),
    "dawn": (["kloppenheim_06_puresky", "qwantani_sunrise_puresky"], ["sunrise", "dawn", "morning"]),
    "night": (["qwantani_night_puresky", "kloppenheim_02_puresky"], ["night"]),
}
TEXTURES = {
    "grass": (["aerial_grass_rock", "rocky_grass", "forrest_ground_01"], ["grass", "meadow"]),
    "dirt": (["brown_mud_leaves_01", "dry_ground_01", "forest_floor"], ["dirt", "soil", "ground", "mud"]),
    "rock": (["rock_face", "rocky_terrain_02", "aerial_rocks_02"], ["rock", "cliff", "stone"]),
    "sand": (["coast_sand_01", "sand_01", "aerial_beach_01"], ["sand", "beach"]),
}
MODELS = {
    "rock": (["namaqualand_boulder_02", "rock_moss_set_01", "boulder_01"], ["rock", "boulder"], 3),
    "bush": (["shrub_01", "shrub_02", "fern_02"], ["shrub", "bush"], 2),
}


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def download(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r, open(path, "wb") as f:
        while True:
            chunk = r.read(1 << 16)
            if not chunk:
                break
            f.write(chunk)


def choose(catalog, preferred, tags, count=1, category=None):
    if category:
        catalog = {k: v for k, v in catalog.items() if category in v.get("categories", [])}
    picks = [p for p in preferred if p in catalog]
    if len(picks) < count:
        scored = []
        for aid, info in catalog.items():
            words = " ".join([aid, info.get("name", "")] + info.get("tags", []) + info.get("categories", [])).lower()
            score = sum(1 for t in tags if t in words)
            if score:
                scored.append((-score, -info.get("download_count", 0), aid))
        for _s, _d, aid in sorted(scored):
            if aid not in picks:
                picks.append(aid)
            if len(picks) >= count:
                break
    return picks[:count]


def best(files, key, res, fmt):
    """files[key][res][fmt] yoksa en yakın çözünürlüğe düşer."""
    entry = files.get(key, {})
    for r in [res, "2k", "1k", "4k"]:
        if r in entry and fmt in entry[r]:
            return entry[r][fmt]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--res", default="2k")
    args = ap.parse_args()
    manifest_path = os.path.join(ROOT, "assets/sources.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}

    def fresh(out, slot, aid):
        """Dosya var ve aynı varlıktan indirildiyse True (seçim değiştiyse yeniden indirilir)."""
        return os.path.exists(out) and manifest.get(slot) == aid

    credits = ["# Varlık Kaynakları", "", "Aşağıdaki varlıklar Poly Haven'dan alınmıştır (CC0, https://polyhaven.com/license).", ""]

    hdris = get_json(f"{API}/assets?t=hdris")
    for slot, (pref, tags) in HDRIS.items():
        aid = choose(hdris, pref, tags, category="pure skies")[0]
        print(f"HDRI {slot}: {aid}")
        credits.append(f"- Gökyüzü ({slot}): [{aid}](https://polyhaven.com/a/{aid})")
        if args.list:
            continue
        out = os.path.join(ROOT, f"assets/hdri/{slot}.hdr")
        if not fresh(out, "hdri/" + slot, aid):
            f = best(get_json(f"{API}/files/{aid}"), "hdri", args.res, "hdr")
            download(f["url"], out)
            manifest["hdri/" + slot] = aid

    textures = get_json(f"{API}/assets?t=textures")
    for slot, (pref, tags) in TEXTURES.items():
        aid = choose(textures, pref, tags)[0]
        print(f"Doku {slot}: {aid}")
        credits.append(f"- Doku ({slot}): [{aid}](https://polyhaven.com/a/{aid})")
        if args.list:
            continue
        files = get_json(f"{API}/files/{aid}")
        for key, name in [("Diffuse", "albedo"), ("nor_gl", "normal")]:
            out = os.path.join(ROOT, f"assets/textures/{slot}_{name}.jpg")
            if fresh(out, f"textures/{slot}_{name}", aid):
                continue
            f = best(files, key, args.res, "jpg") or best(files, key, args.res, "png")
            if f is None:
                print(f"  {key} bulunamadı")
                continue
            download(f["url"], out)
            manifest[f"textures/{slot}_{name}"] = aid

    models = get_json(f"{API}/assets?t=models")
    for slot, (pref, tags, count) in MODELS.items():
        for i, aid in enumerate(choose(models, pref, tags, count)):
            print(f"Model {slot}_{i}: {aid}")
            credits.append(f"- Model ({slot}): [{aid}](https://polyhaven.com/a/{aid})")
            if args.list:
                continue
            base = os.path.join(ROOT, f"assets/models/{slot}_{i}")
            if fresh(base + ".gltf", f"models/{slot}_{i}", aid):
                continue
            f = best(get_json(f"{API}/files/{aid}"), "gltf", "1k", "gltf")
            if f is None:
                print("  gltf bulunamadı")
                continue
            # .gltf ana dosya; dokular ve .bin aynı klasöre, göreli yollarıyla
            download(f["url"], base + ".gltf")
            for rel, inc in f.get("include", {}).items():
                download(inc["url"], os.path.join(os.path.dirname(base), rel))
            manifest[f"models/{slot}_{i}"] = aid

    if not args.list:
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, sort_keys=True)
        with open(os.path.join(ROOT, "assets/CREDITS.md"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(credits) + "\n")
    print("Tamam.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.URLError as e:
        sys.exit(f"Poly Haven'a erişilemedi: {e}")
