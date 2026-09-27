#!/usr/bin/env python3
"""Builds the Microsoft Store package (.msix) of Skyline Rush.

    python3 tools/make_msix.py --exe build/SkylineRush.exe --out SkylineRush.msix \
        --name  <Package/Identity/Name>             (Partner Center > Product identity)
        --publisher "<Package/Identity/Publisher>"  (e.g. "CN=1A2B3C4D-....")
        --publisher-name "<Package/Properties/PublisherDisplayName>"
        [--version 11.0.0.0] [--makemsix /path/to/makemsix]

The three identity values must be copied exactly from Partner Center
(your app > Product management > Product identity), otherwise the upload is
rejected. The package is left unsigned: the Store signs it on submission.

Contents: the exported game (one .exe with the game data embedded), the tile
/ store logos generated from icon.png, a splash image from splash.png, and an
AppxManifest.xml for a full-trust Win32 desktop game (Windows 10 1809+).
`makemsix` is Microsoft's MSIX SDK packer (github.com/microsoft/msix-packaging,
built with --pack); on Windows, MakeAppx.exe from the Windows SDK works too:
    MakeAppx pack /d <staging dir> /p SkylineRush.msix
"""
import argparse
import os
import shutil
import subprocess
import sys
from xml.sax.saxutils import escape

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)

DESCRIPTION = ("Endless sky runner: dash across 9 neon tracks, jump, slide, grapple and "
               "wall-run past traffic, ride skateboards, hoverboards and motorbikes, "
               "chain stylish moves and collect upgrades.")

MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap rescap">
  <Identity Name="{name}" Publisher="{publisher}" Version="{version}" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Skyline Rush</DisplayName>
    <PublisherDisplayName>{publisher_name}</PublisherDisplayName>
    <Logo>Assets\\StoreLogo.png</Logo>
    <Description>{description}</Description>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.0" />
  </Dependencies>
  <Resources>
    <Resource Language="en-us" />
  </Resources>
  <Applications>
    <Application Id="SkylineRush" Executable="SkylineRush.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="Skyline Rush" Description="{description}"
        BackgroundColor="transparent"
        Square150x150Logo="Assets\\Square150x150Logo.png" Square44x44Logo="Assets\\Square44x44Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\\Wide310x150Logo.png" Square310x310Logo="Assets\\Square310x310Logo.png"
          Square71x71Logo="Assets\\Square71x71Logo.png" ShortName="Skyline Rush">
          <uap:ShowNameOnTiles>
            <uap:ShowOn Tile="square150x150Logo" />
            <uap:ShowOn Tile="wide310x150Logo" />
            <uap:ShowOn Tile="square310x310Logo" />
          </uap:ShowNameOnTiles>
        </uap:DefaultTile>
        <uap:SplashScreen Image="Assets\\SplashScreen.png" BackgroundColor="#1a0f2e" />
      </uap:VisualElements>
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"""


def _square(icon, size, pad=0.0):
    """The icon centred on a transparent square, `pad` = margin fraction."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = max(1, int(round(size * (1.0 - 2 * pad))))
    ic = icon.resize((inner, inner), Image.LANCZOS)
    im.paste(ic, ((size - inner) // 2, (size - inner) // 2), ic)
    return im


def _wide(icon, splash, w, h):
    """Wide art: the splash picture cropped to the box, icon-free."""
    if splash is None:
        im = Image.new("RGBA", (w, h), (26, 15, 46, 255))
        ic = icon.resize((int(h * 0.8), int(h * 0.8)), Image.LANCZOS)
        im.paste(ic, ((w - ic.width) // 2, (h - ic.height) // 2), ic)
        return im
    sw, sh = splash.size
    scale = max(w / sw, h / sh)
    s = splash.resize((int(sw * scale + 0.5), int(sh * scale + 0.5)), Image.LANCZOS)
    x = (s.width - w) // 2
    y = (s.height - h) // 2
    return s.crop((x, y, x + w, y + h)).convert("RGBA")


def make_assets(dst):
    os.makedirs(dst, exist_ok=True)
    icon = Image.open(os.path.join(SRC, "icon.png")).convert("RGBA")
    sp = os.path.join(SRC, "splash.png")
    splash = Image.open(sp).convert("RGBA") if os.path.exists(sp) else None
    squares = {
        "StoreLogo": (50, 0.0),
        "Square44x44Logo": (44, 0.0),
        "Square71x71Logo": (71, 0.06),
        "Square150x150Logo": (150, 0.12),
        "Square310x310Logo": (310, 0.12),
    }
    for name, (size, pad) in squares.items():
        _square(icon, size, pad).save(os.path.join(dst, name + ".png"))
    _wide(icon, splash, 310, 150).save(os.path.join(dst, "Wide310x150Logo.png"))
    _wide(icon, splash, 620, 300).save(os.path.join(dst, "SplashScreen.png"))

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--exe", required=True, help="exported SkylineRush.exe (game data embedded)")
    ap.add_argument("--out", required=True, help="output .msix")
    ap.add_argument("--name", required=True)
    ap.add_argument("--publisher", required=True)
    ap.add_argument("--publisher-name", required=True)
    ap.add_argument("--version", default="12.0.0.0", help="a.b.c.0 (the Store needs the last part = 0)")
    ap.add_argument("--makemsix", default=os.environ.get("MAKEMSIX", "makemsix"))
    ap.add_argument("--stage", default=None, help="staging folder (default: next to --out)")
    a = ap.parse_args()
    parts = a.version.split(".")
    if len(parts) != 4 or parts[3] != "0" or not all(p.isdigit() for p in parts):
        sys.exit("version must look like 11.0.0.0 (four numbers, the last one 0)")
    if not a.publisher.startswith("CN="):
        sys.exit("publisher must be the full 'CN=...' string from Partner Center")
    stage = a.stage or os.path.splitext(os.path.abspath(a.out))[0] + "_msix_stage"
    if os.path.exists(stage):
        shutil.rmtree(stage)
    os.makedirs(stage)
    shutil.copy2(a.exe, os.path.join(stage, "SkylineRush.exe"))
    pck = os.path.splitext(a.exe)[0] + ".pck"
    if os.path.exists(pck):  # a non-embedded export ships its data next to the exe
        shutil.copy2(pck, os.path.join(stage, "SkylineRush.pck"))
    make_assets(os.path.join(stage, "Assets"))
    with open(os.path.join(stage, "AppxManifest.xml"), "w", encoding="utf-8") as f:
        f.write(MANIFEST.format(name=escape(a.name, {'"': "&quot;"}), publisher=escape(a.publisher, {'"': "&quot;"}),
                                publisher_name=escape(a.publisher_name), version=a.version,
                                description=escape(DESCRIPTION)))
    if os.path.exists(a.out):
        os.remove(a.out)
    subprocess.check_call([a.makemsix, "pack", "-d", stage, "-p", a.out])
    print("wrote", a.out, os.path.getsize(a.out), "bytes")


if __name__ == "__main__":
    main()
