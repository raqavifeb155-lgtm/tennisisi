#!/usr/bin/env python3
"""The club's model pack (docs/club/CLUB_BRIEF.md 8-9, stream H): CC0 models from KayKit
and Kenney, brought to one look and packed into one small glb the game downloads after the
start (like the music).

    python3 tools/club_models.py SRC_DIR            # writes assets/club/models/club_props.glb (+ scripts/club/world/club_pack_info.gd)
    python3 tools/club_models.py SRC_DIR --info     # what each picked model costs

SRC_DIR holds the unpacked sets (folder names as downloaded):
    kaykit-City-Builder-Bits/  kaykit-Furniture-Bits/  kaykit-Restaurant-Bits/
    kenney_car-kit/  kenney_nature-kit/  kenney_city-kit-commercial_2.1/  kenney_city-kit-suburban_20/
(github.com/KayKit-Game-Assets/KayKit-*-1.0 and kenney.nl/assets/*, all CC0 - CREDITS.md).

How the sets become one style:
  * every model is flattened into ONE mesh (all its nodes and primitives);
  * its colours - the sets' atlas textures (KayKit, Kenney colormap) or flat material
    colours (Kenney Nature Kit) - are baked into the vertices and pulled toward the club's
    palette (ClubMaterial.PALETTE): no textures at all, one material for every prop
    (ClubMaterial.tinted), so props of different sets merge into the same draw calls;
  * scaled by the hero (1.85 m): each pick gives its real height in metres; centred on x/z,
    standing on y = 0, facing -z (Godot's forward) as in the sets;
  * vertices deduplicated, positions and normals float32, colours 8-bit, indices 16-bit.
Pure Python (PIL for the atlases), no other packages.
"""
import json
import math
import os
import struct
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "club", "models", "club_props.glb")

KC = "kaykit-City-Builder-Bits/KayKit-City-Builder-Bits-1.0-main/addons/kaykit_city_builder_bits/Assets/gltf/"
KF = "kaykit-Furniture-Bits/KayKit-Furniture-Bits-1.0-main/addons/kaykit_furniture_bits/Assets/gltf/"
KR = "kaykit-Restaurant-Bits/KayKit-Restaurant-Bits-1.0-main/addons/kaykit_restaurant_bits/Assets/gltf/"
NC = "kenney_car-kit/Models/GLB format/"
NN = "kenney_nature-kit/Models/GLTF format/"
NM = "kenney_city-kit-commercial_2.1/Models/GLB format/"
NS = "kenney_city-kit-suburban_20/Models/GLB format/"

# id -> (source file, height in metres, palette pull 0..1[, palette indices it may also land on]). The id is what the game asks for
# (scripts/club/world/club_props.gd); the height sets the scale (the hero is 1.85 m).
PICKS = {
    # the street and the paths (KayKit City Builder Bits)
    "bench": (KC + "bench.gltf", 0.85, 0.5),
    "streetlight": (KC + "streetlight.gltf", 4.2, 0.5),
    "dumpster": (KC + "dumpster.gltf", 1.45, 0.5),
    "hydrant": (KC + "firehydrant.gltf", 0.8, 0.4),
    "box_a": (KC + "box_A.gltf", 0.55, 0.5),
    "box_b": (KC + "box_B.gltf", 0.45, 0.5),
    "car_hatch": (KC + "car_hatchback.gltf", 1.5, 0.35),
    "car_sedan": (KC + "car_sedan.gltf", 1.45, 0.35),
    "car_wagon": (KC + "car_stationwagon.gltf", 1.6, 0.35),
    "watertower": (KC + "watertower.gltf", 5.0, 0.5),
    "building_a": (KC + "building_A_withoutBase.gltf", 9.0, 0.45),
    "building_b": (KC + "building_B_withoutBase.gltf", 10.0, 0.45),
    # what a worn-out club has lying around (KayKit Furniture Bits)
    "armchair": (KF + "armchair.gltf", 0.9, 0.45),
    "chair_wood": (KF + "chair_A_wood.gltf", 0.95, 0.5),
    "table_low": (KF + "table_low.gltf", 0.45, 0.5),
    # the bar's terrace and the kiosks (KayKit Restaurant Bits)
    "bar_table": (KR + "table_round_A.gltf", 0.78, 0.5),
    "bar_chair": (KR + "chair_B.gltf", 0.95, 0.5),
    "bar_stool": (KR + "chair_stool.gltf", 0.75, 0.5),
    "crate": (KR + "crate.gltf", 0.5, 0.5),
    "menu_board": (KR + "menu.gltf", 0.6, 0.4),
    # trees, bushes, flowers, rocks, wood (Kenney Nature Kit)
    "tree_oak": (NN + "tree_oak.glb", 6.5, 0.88),
    "tree_round": (NN + "tree_default.glb", 6.0, 0.88),
    "tree_tall": (NN + "tree_detailed.glb", 7.5, 0.88),
    "tree_fat": (NN + "tree_fat.glb", 5.5, 0.88),
    "tree_small": (NN + "tree_small.glb", 4.0, 0.88),
    "tree_pine": (NN + "tree_pineTallA.glb", 8.0, 0.88),
    "tree_pine_small": (NN + "tree_pineSmallA.glb", 3.5, 0.88),
    "bush": (NN + "plant_bush.glb", 0.8, 0.88),
    "bush_large": (NN + "plant_bushLarge.glb", 1.2, 0.88),
    "flowers_red": (NN + "flower_redA.glb", 0.35, 0.3),
    "flowers_yellow": (NN + "flower_yellowA.glb", 0.35, 0.3),
    "flowers_purple": (NN + "flower_purpleA.glb", 0.35, 0.3),
    "rock": (NN + "rock_smallA.glb", 0.35, 0.5),
    "stone_tall": (NN + "stone_tallA.glb", 1.6, 0.5),
    "column_broken": (NN + "statue_columnDamaged.glb", 1.7, 0.5),
    "stump": (NN + "stump_round.glb", 0.45, 0.5),
    "log": (NN + "log.glb", 0.35, 0.5),
    "log_stack": (NN + "log_stack.glb", 0.7, 0.5),
    "planter": (NN + "pot_large.glb", 0.8, 0.5),
    "sign": (NN + "sign.glb", 1.3, 0.5),
    "fence_planks": (NN + "fence_planks.glb", 0.9, 0.5),
    # parking, the street front (Kenney Car Kit, City Kit)
    "cone": (NC + "cone.glb", 0.7, 0.3, (30,)),
    "tyre": (NC + "debris-tire.glb", 0.3, 0.4),
    "bumper": (NC + "debris-bumper.glb", 0.3, 0.4),
    "parasol": (NM + "detail-parasol-a.glb", 2.6, 0.4),
    "awning": (NM + "detail-awning.glb", 0.9, 0.4),
    "shop_a": (NM + "low-detail-building-a.glb", 12.0, 0.45),
    "shop_b": (NM + "low-detail-building-d.glb", 14.0, 0.45),
    "shop_c": (NM + "low-detail-building-g.glb", 10.0, 0.45),
    "shop_wide_a": (NM + "low-detail-building-wide-a.glb", 9.0, 0.45),
    "shop_wide_b": (NM + "low-detail-building-wide-b.glb", 9.0, 0.45),
    "fence_low": (NS + "fence-low.glb", 0.6, 0.5),
    "fence": (NS + "fence-1x4.glb", 1.0, 0.5),
}

# ClubMaterial.PALETTE (scripts/club/club_material.gd) and the park's leaves (scenery.gd).
PALETTE = [
    "2a54a3", "3d806a", "f5f5f5", "8f8a80", "5e5a54", "c08a55", "6b4a32", "25272b", "b9bec4", "8c4a2a",
    "a0523d", "e3d6c3", "8fb8c9", "4d7a33", "668f3b", "436b38", "ffd642", "ffe27a", "2a54a3", "1e3a73",
    "f2f0ea", "d9473b", "1e2a44", "141219", "9e968a", "bdb3a3", "ede3cc", "29392f", "6b7f94", "3fb8af",
    "f08a3c", "101114",
    "4d7a33", "668f3b", "436b38", "77953f",   # scenery.gd LEAVES (rgb of 0.3,0.48,0.2 ...)
]
PALETTE = [tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) for h in PALETTE]

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# --- reading glTF --------------------------------------------------------------------

class Gltf:
    def __init__(self, path):
        self.dir = os.path.dirname(path)
        data = open(path, "rb").read()
        self.bin = None
        if data[:4] == b"glTF":
            jl = struct.unpack("<I", data[12:16])[0]
            self.j = json.loads(data[20:20 + jl])
            off = 20 + jl
            if off < len(data):
                bl = struct.unpack("<I", data[off:off + 4])[0]
                self.bin = data[off + 8:off + 8 + bl]
        else:
            self.j = json.loads(data)
        self.buffers = []
        for b in self.j.get("buffers", []):
            if "uri" in b:
                self.buffers.append(open(os.path.join(self.dir, b["uri"]), "rb").read())
            else:
                self.buffers.append(self.bin)
        self.images = {}

    def accessor(self, i):
        a = self.j["accessors"][i]
        fmt, size = COMP[a["componentType"]]
        n = NCOMP[a["type"]]
        bv = self.j["bufferViews"][a["bufferView"]]
        buf = self.buffers[bv["buffer"]]
        base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", size * n)
        out = []
        norm = a.get("normalized", False)
        mx = {"b": 127.0, "B": 255.0, "h": 32767.0, "H": 65535.0}.get(fmt, 1.0)
        for k in range(a["count"]):
            v = struct.unpack_from("<" + fmt * n, buf, base + k * stride)
            if norm:
                v = tuple(max(-1.0, x / mx) for x in v)
            out.append(v)
        return out

    def image(self, tex_index):
        if tex_index in self.images:
            return self.images[tex_index]
        tex = self.j["textures"][tex_index]
        img = self.j["images"][tex["source"]]
        if "uri" in img:
            im = Image.open(os.path.join(self.dir, img["uri"]))
        else:
            import io
            bv = self.j["bufferViews"][img["bufferView"]]
            buf = self.buffers[bv["buffer"]]
            o = bv.get("byteOffset", 0)
            im = Image.open(io.BytesIO(buf[o:o + bv["byteLength"]]))
        im = im.convert("RGB")
        self.images[tex_index] = im
        return im


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    q = n.get("rotation", [0, 0, 0, 1])
    s = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [
        [r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], t[0]],
        [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], t[1]],
        [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], t[2]],
        [0, 0, 0, 1],
    ]


def flatten(g):
    """All triangles of the default scene: list of (pos, normal, colour) per corner."""
    tris = []
    scene = g.j.get("scenes", [{"nodes": list(range(len(g.j.get("nodes", []))))}])[g.j.get("scene", 0)]
    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    def walk(ni, parent):
        n = g.j["nodes"][ni]
        m = mat_mul(parent, node_matrix(n))
        if "mesh" in n:
            for prim in g.j["meshes"][n["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                tris.extend(primitive(g, prim, m))
        for c in n.get("children", []):
            walk(c, m)

    for ni in scene["nodes"]:
        walk(ni, ident)
    return tris


def primitive(g, prim, m):
    at = prim["attributes"]
    pos = g.accessor(at["POSITION"])
    nrm = g.accessor(at["NORMAL"]) if "NORMAL" in at else None
    uv = g.accessor(at["TEXCOORD_0"]) if "TEXCOORD_0" in at else None
    idx = [i[0] for i in g.accessor(prim["indices"])] if "indices" in prim else list(range(len(pos)))
    mat = g.j["materials"][prim["material"]] if "material" in prim else {}
    pbr = mat.get("pbrMetallicRoughness", {})
    factor = pbr.get("baseColorFactor", [1, 1, 1, 1])
    img = g.image(pbr["baseColorTexture"]["index"]) if "baseColorTexture" in pbr and uv else None
    cols = []
    for k in range(len(pos)):
        c = [factor[0], factor[1], factor[2]]
        if img is not None:
            u, v = uv[k]
            px = img.getpixel((int((u % 1.0) * img.width) % img.width, int((v % 1.0) * img.height) % img.height))
            c = [c[0] * px[0] / 255.0, c[1] * px[1] / 255.0, c[2] * px[2] / 255.0]
        cols.append(c)
    lin = [[m[r][0], m[r][1], m[r][2]] for r in range(3)]
    out = []
    for k in idx:
        p = pos[k]
        wp = [lin[r][0] * p[0] + lin[r][1] * p[1] + lin[r][2] * p[2] + m[r][3] for r in range(3)]
        if nrm:
            nn = nrm[k]
            wn = [lin[r][0] * nn[0] + lin[r][1] * nn[1] + lin[r][2] * nn[2] for r in range(3)]
        else:
            wn = [0, 1, 0]
        out.append((wp, wn, cols[k]))
    return out


# --- the club's look -----------------------------------------------------------------

def srgb_to_linear(c):
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def to_lab(c):
    # Good enough perceptual space for picking the nearest palette colour (sRGB in).
    r, g, b = srgb_to_linear(c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))


PAL_LAB = [to_lab(p) for p in PALETTE]


# Colours the nearest-palette search never lands on unless a pick asks for them: they
# would turn a green leaf teal and a plank orange (gold, neon, soda teal, orange, the
# court's out-of-bounds green).
EXCLUDE = {1, 16, 17, 29, 30}


# Kenney's Nature Kit paints its leaves a minty teal (0.16, 0.79, 0.67) and its wood salmon:
# its colours may only land on greens, woods, stones and whites.
NATURE = {2, 3, 4, 6, 13, 14, 15, 20, 24, 25, 26, 32, 33, 34, 35}


def club_colour(c, pull, allow=()):
    """Pulls a colour toward the nearest palette colour (pull 1 = exactly it); the sets'
    colours keep a little of themselves, so a model doesn't go flat."""
    lab = to_lab(c)
    if allow == "nature":
        ok = sorted(NATURE)
    else:
        ok = [i for i in range(len(PALETTE)) if i not in EXCLUDE or i in allow]
    best = min(ok, key=lambda i: sum((lab[k] - PAL_LAB[i][k]) ** 2 for k in range(3)))
    p = PALETTE[best]
    return [c[k] + (p[k] - c[k]) * pull for k in range(3)]


def bake(path, height, pull, allow=()):
    g = Gltf(path)
    tris = flatten(g)
    lo = [min(t[0][k] for t in tris) for k in range(3)]
    hi = [max(t[0][k] for t in tris) for k in range(3)]
    s = height / max(hi[1] - lo[1], 1e-6)
    cx = (lo[0] + hi[0]) * 0.5
    cz = (lo[2] + hi[2]) * 0.5
    verts = {}
    vlist = []
    idx = []
    colour_cache = {}
    for p, n, c in tris:
        key_c = tuple(round(x, 3) for x in c)
        if key_c not in colour_cache:
            colour_cache[key_c] = club_colour(c, pull, allow)
        cc = colour_cache[key_c]
        q = ((p[0] - cx) * s, (p[1] - lo[1]) * s, (p[2] - cz) * s)
        ln = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2) or 1.0
        nn = (n[0] / ln, n[1] / ln, n[2] / ln)
        col = tuple(max(0, min(255, int(round(x * 255)))) for x in cc)
        key = (tuple(round(x, 4) for x in q), tuple(round(x, 3) for x in nn), col)
        i = verts.get(key)
        if i is None:
            i = len(vlist)
            verts[key] = i
            vlist.append((q, nn, col))
        idx.append(i)
    # glTF winding is counter-clockwise like Godot's import expects: keep it.
    return vlist, idx


# --- writing one glb -----------------------------------------------------------------

def write_glb(models, out):
    bin_ = bytearray()
    j = {"asset": {"version": "2.0", "generator": "tennisisi tools/club_models.py"},
         "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [],
         "bufferViews": [], "buffers": [],
         "materials": [{"name": "club_props", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.8}}]}

    def view(data, target):
        while len(bin_) % 4:
            bin_.append(0)
        off = len(bin_)
        bin_.extend(data)
        j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(j["bufferViews"]) - 1

    def acc(bv, ctype, count, typ, mn=None, mx=None, normalized=False):
        a = {"bufferView": bv, "componentType": ctype, "count": count, "type": typ}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        if normalized:
            a["normalized"] = True
        j["accessors"].append(a)
        return len(j["accessors"]) - 1

    for name, (verts, idx) in models.items():
        pos = b"".join(struct.pack("<3f", *v[0]) for v in verts)
        nrm = b"".join(struct.pack("<3f", *v[1]) for v in verts)
        col = b"".join(struct.pack("<4B", v[2][0], v[2][1], v[2][2], 255) for v in verts)
        ind = struct.pack("<%dH" % len(idx), *idx)
        mn = [min(v[0][k] for v in verts) for k in range(3)]
        mx = [max(v[0][k] for v in verts) for k in range(3)]
        a_p = acc(view(pos, 34962), 5126, len(verts), "VEC3", mn, mx)
        a_n = acc(view(nrm, 34962), 5126, len(verts), "VEC3")
        a_c = acc(view(col, 34962), 5121, len(verts), "VEC4", normalized=True)
        a_i = acc(view(ind, 34963), 5123, len(idx), "SCALAR")
        j["meshes"].append({"name": name, "primitives": [{"attributes": {"POSITION": a_p, "NORMAL": a_n, "COLOR_0": a_c}, "indices": a_i, "material": 0}]})
        j["nodes"].append({"name": name, "mesh": len(j["meshes"]) - 1})
        j["scenes"][0]["nodes"].append(len(j["nodes"]) - 1)
    while len(bin_) % 4:
        bin_.append(0)
    j["buffers"].append({"byteLength": len(bin_)})
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(out, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\x00"))
        f.write(bin_)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    info = "--info" in sys.argv
    models = {}
    total_tris = 0
    for name, pick in PICKS.items():
        rel, height, pull = pick[:3]
        allow = pick[3] if len(pick) > 3 else ()
        if rel.startswith(NN) and not allow and not name.startswith("flowers"):
            allow = "nature"
        path = os.path.join(src, rel)
        if not os.path.exists(path):
            print("MISSING %s: %s" % (name, rel))
            continue
        verts, idx = bake(path, height, pull, allow)
        models[name] = (verts, idx)
        total_tris += len(idx) // 3
        if info:
            print("%-16s %5d tris %5d verts  %s" % (name, len(idx) // 3, len(verts), rel.split("/")[0]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    write_glb(models, OUT)
    import gzip
    import hashlib
    raw = open(OUT, "rb").read()
    # The page serves the pack as models/club_props.<version>.glb (tools/build_web.sh): a new
    # pack is a new name, so a browser can keep the old one for good.
    ver = hashlib.sha256(raw).hexdigest()[:10]
    info = os.path.join(ROOT, "scripts", "club", "world", "club_pack_info.gd")
    with open(info, "w", newline="\n") as f:
        f.write("class_name ClubPackInfo\n## Written by tools/club_models.py: which pack the game asks the page for (models/club_props.<VERSION>.glb).\n\n")
        f.write('const VERSION := "%s"\n' % ver)
        f.write("const IDS := [%s]\n" % ", ".join('"%s"' % k for k in models))
    print("%d models, %d triangles -> %s (%.0f KB, %.0f KB gzip)" % (len(models), total_tris, OUT, len(raw) / 1024, len(gzip.compress(raw, 9)) / 1024))


if __name__ == "__main__":
    main()
