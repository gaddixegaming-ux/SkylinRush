#!/usr/bin/env python3
"""Builds the MOBILE edition of Skyline Rush from this project.

    python3 tools/make_mobile.py <out_dir>

The copy is the same game, set up for phones / tablets (including low-end ones):
  - PORTRAIT: played vertically (1080x1920 layout, portrait orientation)
  - the Compatibility renderer (OpenGL ES 3) - the fastest one on low-end
    Android GPUs; no SSAO / SSIL, a cheap baked-style contact shading instead
  - every texture capped at 1024 px (the 4K model textures and 2K character
    textures are downscaled), so it loads fast and uses little GPU memory
  - small shadow maps, no MSAA, lower 3D render resolution (the auto
    performance governor lowers it further if the frame rate drops)
  - touch controls on by default (swipes, double-tap = HOOK, DASH button),
    mouse drags act as touches so it can be tried on a PC
  - an Android export preset (arm64) - open in Godot 4.3 and export, or run
    godot --headless --export-release "Android" build/SkylineRush.apk
"""
import os
import re
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
MAX_TEX = 1024


def _set(s, section, key, value):
    """Sets key=value inside [section] of a project.godot text."""
    line = "%s=%s" % (key, value)
    m = re.search(r"^\[%s\]\n" % re.escape(section), s, re.M)
    if not m:
        return s.rstrip("\n") + "\n\n[%s]\n\n%s\n" % (section, line)
    end = s.find("\n[", m.end())
    end = len(s) if end < 0 else end + 1
    body = s[m.end():end]
    pat = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pat.search(body):
        body = pat.sub(line, body)
    else:
        body = "\n" + line + body if not body.startswith("\n") else "\n" + line + body
    return s[:m.end()] + body + s[end:]


def _shrink_image(path, max_px):
    im = Image.open(path)
    if max(im.size) <= max_px:
        return
    im.thumbnail((max_px, max_px), Image.LANCZOS)
    if path.lower().endswith(".png"):
        im.save(path, optimize=True)
    else:
        im.convert("RGB").save(path, quality=88)
    print("  %s -> %s" % (os.path.relpath(path), im.size))


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(SRC, "..", "skyline_rush_mobile"))
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(SRC, out, ignore=shutil.ignore_patterns(".godot", "shots", "build", "__pycache__", "*.tmp"))

    # ---- project settings
    p = os.path.join(out, "project.godot")
    s = open(p).read()
    s = s.replace('config/name="Skyline Rush"', 'config/name="Skyline Rush Mobile"')
    s = re.sub(r'config/features=PackedStringArray\("4.3", "[^"]+"\)', 'config/features=PackedStringArray("4.3", "GL Compatibility")', s)
    s = re.sub(r"anti_aliasing/quality/msaa_3d=\d+\n", "", s)
    s = _set(s, "rendering", "renderer/rendering_method", '"gl_compatibility"')
    s = _set(s, "rendering", "renderer/rendering_method.mobile", '"gl_compatibility"')
    s = _set(s, "rendering", "lights_and_shadows/directional_shadow/size", "1024")
    s = _set(s, "rendering", "lights_and_shadows/directional_shadow/size.mobile", "1024")
    s = _set(s, "rendering", "lights_and_shadows/directional_shadow/soft_shadow_filter_quality", "0")
    s = _set(s, "rendering", "lights_and_shadows/positional_shadow/soft_shadow_filter_quality", "0")
    s = _set(s, "rendering", "lights_and_shadows/positional_shadow/atlas_size", "1024")
    s = _set(s, "rendering", "anti_aliasing/quality/msaa_3d", "0")
    s = _set(s, "rendering", "textures/default_filters/anisotropic_filtering_level", "1")
    # portrait: the whole layout is built for a tall 1080x1920 screen
    s = _set(s, "display", "window/size/viewport_width", "1080")
    s = _set(s, "display", "window/size/viewport_height", "1920")
    s = _set(s, "display", "window/handheld/orientation", "1")
    s = _set(s, "display", "window/size/mode", "0")
    s = _set(s, "display", "window/size/window_width_override", "540")
    s = _set(s, "display", "window/size/window_height_override", "960")
    s = _set(s, "skyline", "mobile_build", "true")
    s = _set(s, "input_devices", "pointing/emulate_touch_from_mouse", "true")
    open(p, "w").write(s)

    # ---- smaller textures (4K / 2K -> 1K)
    glbs = [os.path.join(out, "models", f) for f in os.listdir(os.path.join(out, "models")) if f.endswith(".glb")]
    subprocess.check_call([sys.executable, os.path.join(HERE, "shrink_glb.py"), "--max", str(MAX_TEX)] + glbs)
    for f in os.listdir(os.path.join(out, "models")):
        if re.search(r"_(futuristic|stylized).*\.(jpg|png)(\.import)?$", f):
            os.remove(os.path.join(out, "models", f))  # re-extracted from the smaller GLBs on import
    for root, _dirs, files in os.walk(out):
        for f in files:
            if f.lower().endswith((".jpg", ".jpeg", ".png")) and "/tools/" not in root + "/":
                _shrink_image(os.path.join(root, f), MAX_TEX if "splash" not in f else 1280)

    # ---- Android only
    e = open(os.path.join(SRC, "export_presets.cfg")).read()
    i = e.index('[preset.2]')
    android = e[i:].replace("[preset.2]", "[preset.0]").replace("[preset.2.options]", "[preset.0.options]")
    android = re.sub(r"screen/orientation=\d+", "screen/orientation=1", android)
    open(os.path.join(out, "export_presets.cfg"), "w").write(android)
    print("mobile edition written to", out)


if __name__ == "__main__":
    main()
