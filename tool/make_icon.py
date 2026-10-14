#!/usr/bin/env python3
"""assets/icon/app_icon.svg dosyasından simge üretir (Chrome ile işler, Pillow ile ICO'ya çevirir).

Çıktılar
  assets/icon/app_icon.png                    1024x1024 (şeffaf köşeli)
  windows/runner/resources/app_icon.ico       16–256 px
  android/app/src/main/res/mipmap-*/ic_launcher.png   (Android klasörü varsa)

Gereken: Google Chrome (ya da Edge) ve `pip install pillow`.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "assets" / "icon" / "app_icon.svg"
BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def render(png: Path, size: int = 1024):
    exe = next((b for b in BROWSERS if Path(b).exists()), None)
    if not exe:
        sys.exit("Chrome/Edge bulunamadı")
    with tempfile.TemporaryDirectory() as prof:
        subprocess.run(
            [exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={prof}",
             "--default-background-color=00000000", f"--window-size={size},{size}",
             f"--screenshot={png}", SVG.as_uri()],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90,
        )


def main():
    png = ROOT / "assets" / "icon" / "app_icon.png"
    render(png)
    im = Image.open(png).convert("RGBA")
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.LANCZOS)
        im.save(png)
    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico.parent.mkdir(parents=True, exist_ok=True)
    im.save(ico, format="ICO", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    if res.exists():
        for d, sz in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
            out = res / f"mipmap-{d}" / "ic_launcher.png"
            if out.parent.exists():
                im.resize((sz, sz), Image.LANCZOS).save(out)
    print("simge üretildi:", png)


if __name__ == "__main__":
    main()
