#!/usr/bin/env python3
"""Builds the MOBILE edition of Skyline Rush from this project.

    python3 tools/make_mobile.py <out_dir>

The copy is the same game, set up for phones / tablets:
  - Godot's Mobile renderer everywhere (no SSAO / SSIL global illumination;
    a cheap baked-style contact shading is used instead)
  - touch controls on by default (swipes + DASH / HOOK buttons), mouse drags
    act as touches so it can be tried on a PC
  - landscape (sensor), immersive fullscreen
  - model textures capped at 2048 px (smaller download, less GPU memory)
  - an Android export preset (arm64) - open in Godot 4.3 and export, or run
    godot --headless --export-release "Android" build/SkylineRush.apk
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(SRC, "..", "skyline_rush_mobile"))
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(SRC, out, ignore=shutil.ignore_patterns(".godot", "shots", "build", "__pycache__", "*.tmp"))

    # ---- project settings
    p = os.path.join(out, "project.godot")
    s = open(p).read()
    s = s.replace('config/name="Skyline Rush"', 'config/name="Skyline Rush Mobile"')
    s = s.replace('config/features=PackedStringArray("4.3", "Forward Plus")', 'config/features=PackedStringArray("4.3", "Mobile")')
    s = s.replace("[rendering]\n", '[rendering]\n\nrenderer/rendering_method="mobile"\n', 1)
    s = re.sub(r"anti_aliasing/quality/msaa_3d=\d+\n", "", s)
    s += '\n[skyline]\n\nmobile_build=true\n\n[input_devices]\n\npointing/emulate_touch_from_mouse=true\n'
    open(p, "w").write(s)

    # ---- smaller textures in the vehicle / tree models
    glbs = [os.path.join(out, "models", f) for f in os.listdir(os.path.join(out, "models")) if f.endswith(".glb")]
    subprocess.check_call([sys.executable, os.path.join(HERE, "shrink_glb.py")] + glbs)
    for f in os.listdir(os.path.join(out, "models")):
        if re.search(r"_(futuristic|stylized).*\.(jpg|png)(\.import)?$", f):
            os.remove(os.path.join(out, "models", f))  # re-extracted from the smaller GLBs on import

    # ---- Android only
    e = open(os.path.join(SRC, "export_presets.cfg")).read()
    i = e.index('[preset.2]')
    android = e[i:].replace("[preset.2]", "[preset.0]").replace("[preset.2.options]", "[preset.0.options]")
    android = android.replace('package/name="Skyline Rush"', 'package/name="Skyline Rush"')
    open(os.path.join(out, "export_presets.cfg"), "w").write(android)
    print("mobile edition written to", out)


if __name__ == "__main__":
    main()
