#!/usr/bin/env python3
"""Oyundaki bütün replikleri Google Cloud Text-to-Speech ile Türkçe erkek sesiyle seslendirir.

Kullanım:
    export GOOGLE_TTS_API_KEY=...        # anahtar asla depoya yazılmaz
    python3 tools/generate_voices.py     # eksik dosyaları üretir
    python3 tools/generate_voices.py --dry-run   # yalnızca replikleri listeler
    python3 tools/generate_voices.py --force     # hepsini yeniden üretir

Çıktılar:
    assets/voices/<anahtar>.mp3          Voice.LINES içindeki kısa naralar (Allah Allah, Hücum...)
    assets/voices/lines/<md5>.mp3        Konuşmalar ve intro anlatımları (metnin UTF-8 md5'i)
    assets/voices/lines/manifest.json    Hangi dosyanın hangi metin ve sesle üretildiği
"""
import argparse
import base64
import glob
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://texttospeech.googleapis.com/v1"
STR = r'"((?:[^"\\]|\\.)*)"'


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def collect_lines():
    """(metin, konuşan) çiftleri: "kemal", "anlatici" ya da "asker"."""
    lines = []
    shouts = {}
    voice_src = open(os.path.join(ROOT, "scripts/core/voice.gd"), encoding="utf-8").read()
    block = voice_src[voice_src.index("const LINES"):voice_src.index("}", voice_src.index("const LINES"))]
    for key, text in re.findall(r'"(\w+)":\s*' + STR, block):
        shouts[key] = unescape(text)
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True)):
        src = open(path, encoding="utf-8").read()
        for who, text in re.findall(r'\bsay\(\s*(k|"[^"]*")\s*,\s*' + STR, src):
            speaker = "kemal" if who == "k" or "Kemal" in who else "asker"
            lines.append((unescape(text), speaker))
        for text, who in re.findall(r"Voice\.speak\(\s*" + STR + r'\s*(?:,\s*"(\w+)")?', src):
            lines.append((unescape(text), "kemal" if who == "kemal" else "asker"))
        if "func intro_cards" in src:
            start = src.index("func intro_cards")
            nxt = src.find("\nfunc ", start + 10)
            body = src[start:nxt if nxt > 0 else len(src)]
            for _title, text in re.findall(r"\[\s*" + STR + r"\s*,\s*" + STR + r"\s*\]", body):
                lines.append((unescape(text), "anlatici"))
    seen = set()
    unique = []
    for text, who in lines:
        if text not in seen:
            seen.add(text)
            unique.append((text, who))
    return shouts, unique


def request(url, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def pick_voices(key):
    """Türkçe erkek seslerinden en doğal olanları seçer: Chirp3-HD > WaveNet > Standard."""
    voices = request(f"{API}/voices?languageCode=tr-TR&key={key}").get("voices", [])
    male = [v["name"] for v in voices if v.get("ssmlGender") == "MALE" and v["name"].startswith("tr-TR")]

    def rank(name):
        for i, tier in enumerate(["Chirp3-HD", "Chirp-HD", "Neural2", "Wavenet", "Standard"]):
            if tier in name:
                return i
        return 9

    male.sort(key=rank)
    if not male:
        sys.exit("Türkçe erkek sesi bulunamadı.")
    pick = lambda i: male[min(i, len(male) - 1)]
    return {"kemal": pick(0), "anlatici": pick(1), "asker": pick(2)}


def synthesize(key, text, voice, rate):
    cfg = {"audioEncoding": "MP3", "sampleRateHertz": 44100}
    if "Chirp" not in voice:
        cfg["speakingRate"] = rate
    body = {"input": {"text": text}, "voice": {"languageCode": "tr-TR", "name": voice}, "audioConfig": cfg}
    return base64.b64decode(request(f"{API}/text:synthesize?key={key}", body)["audioContent"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    shouts, lines = collect_lines()
    if args.dry_run:
        for k, t in shouts.items():
            print(f"[nara] {k}: {t}")
        for t, w in lines:
            print(f"[{w}] {t[:90]}")
        print(f"{len(shouts)} nara, {len(lines)} replik")
        return
    key = os.environ.get("GOOGLE_TTS_API_KEY", "")
    if not key:
        sys.exit("GOOGLE_TTS_API_KEY ortam değişkeni tanımlı değil.")
    voices = pick_voices(key)
    print("Seçilen sesler:", voices)
    rates = {"kemal": 0.92, "anlatici": 0.95, "asker": 1.05}
    out_dir = os.path.join(ROOT, "assets/voices")
    lines_dir = os.path.join(out_dir, "lines")
    os.makedirs(lines_dir, exist_ok=True)
    manifest = {}
    jobs = [(os.path.join(out_dir, f"{k}.mp3"), t, "asker") for k, t in shouts.items()]
    for t, w in lines:
        jobs.append((os.path.join(lines_dir, hashlib.md5(t.encode("utf-8")).hexdigest() + ".mp3"), t, w))
    made = 0
    for path, text, who in jobs:
        if path.startswith(lines_dir):
            manifest[os.path.basename(path)] = {"text": text, "speaker": who, "voice": voices[who]}
        if os.path.exists(path) and not args.force:
            continue
        try:
            audio = synthesize(key, text, voices[who], rates[who])
        except urllib.error.HTTPError as e:
            print(f"HATA ({e.code}) {text[:60]}: {e.read().decode('utf-8', 'replace')[:200]}")
            continue
        with open(path, "wb") as f:
            f.write(audio)
        made += 1
        print(f"✓ [{who}] {text[:70]}")
    with open(os.path.join(lines_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"{made} dosya üretildi.")


if __name__ == "__main__":
    main()
