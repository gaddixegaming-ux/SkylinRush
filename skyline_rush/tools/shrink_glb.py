#!/usr/bin/env python3
"""Run: python3 tools/shrink_glb.py [--max 1024] models/*.glb
Downscale the textures embedded in GLB files (default max 2048 px) to keep the download small."""
import io, json, struct, sys
from PIL import Image

def shrink(path, max_px=2048):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', b[off:off + 4])[0]
    binc = b[off + 8:off + 8 + bl]
    views = j['bufferViews']
    img_views = {im['bufferView']: im for im in j.get('images', [])}
    out = bytearray()
    for i, v in enumerate(views):
        data = binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        if i in img_views:
            im = Image.open(io.BytesIO(data))
            info = (im.mode, im.size)
            if max(im.size) > max_px:
                im.thumbnail((max_px, max_px), Image.LANCZOS)
            buf = io.BytesIO()
            if img_views[i].get('mimeType') == 'image/png' and im.mode in ('RGBA', 'LA', 'P') and im.convert('RGBA').getextrema()[3][0] < 255:
                im.save(buf, 'PNG', optimize=True)
                img_views[i]['mimeType'] = 'image/png'
            else:
                im.convert('RGB').save(buf, 'JPEG', quality=88)
                img_views[i]['mimeType'] = 'image/jpeg'
            data = buf.getvalue()
            print('  ', info, '->', im.size, len(data))
        while len(out) % 4:
            out.append(0)
        v['byteOffset'] = len(out)
        v['byteLength'] = len(data)
        v['buffer'] = 0
        out += data
    while len(out) % 4:
        out.append(0)
    j['buffers'] = [{'byteLength': len(out)}]
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4:
        js += b' '
    total = 12 + 8 + len(js) + 8 + len(out)
    res = struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(out), 0x004E4942) + bytes(out)
    open(path, 'wb').write(res)
    print(path, len(b), '->', len(res))

args = sys.argv[1:]
mx = 2048
if args and args[0] == '--max':
    mx = int(args[1])
    args = args[2:]
for p in args:
    shrink(p, mx)
