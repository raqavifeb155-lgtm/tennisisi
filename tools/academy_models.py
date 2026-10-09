#!/usr/bin/env python3
"""The Academy house's model pack (docs/academy/ASSETS.md, ART_BRIEF.md): CC0 furniture of
KayKit (Furniture Bits, Restaurant Bits, Prototype Bits), brought to the club's look and
composed into LEVELLED sets - a bed, a kitchen, a sofa each come as `_1` (worn out) ... `_4`
(premium) - then packed into one small glb the game downloads after the start, like the
club's pack (scripts/academy/house/house_pack.gd).

    python3 tools/academy_models.py SRC_DIR            # writes assets/academy/models/academy_props.glb
                                                       # (+ scripts/academy/house/house_pack_info.gd)
    python3 tools/academy_models.py SRC_DIR --info     # what each model costs

SRC_DIR holds the unpacked sets (git clone --depth 1 of github.com/KayKit-Game-Assets/KayKit-*-1.0):
    kaykit-Furniture-Bits/  kaykit-Restaurant-Bits/  kaykit-Prototype-Bits/
Everything the sets do not have (gym machines, screens, the ball machine, lockers, the
facade...) is made in code: scripts/academy/house/house_shapes.gd. Every pack id has a
simple code form there too, so the house stands before the pack arrives.

It reuses tools/club_models.py (glTF reading, the palette pull, the glb writer) and adds:
  * parts: a model of a set placed (offset, yaw, scale) inside a composed model, plus code
    primitives (box, cylinder) for the accents the sets lack (a blanket in the club's blue,
    a tablecloth);
  * `wear`: pulls the colours toward dusty grey-brown and darkens them - the worn-out levels;
  * the palette grows by the house's interior colours (blush, sage, mustard, plum...);
  * the club's blue (2a54a3 / 1e3a73) stays exactly itself in the vertices: the game may
    swap those two colours for the club colour the player chose (HousePack.club_tint).
The sets' native unit is ~1.5x a metre (a bed is 3 long): scales below bring them to metres.
Facing: the front of every model looks to +z, standing on y = 0, centred on x/z.
"""
import colorsys
import math
import os
import struct
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import club_models as cm  # noqa: E402  (reused: Gltf, flatten, club_colour, write_glb, palette)

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "academy", "models", "academy_props.glb")
INFO = os.path.join(ROOT, "scripts", "academy", "house", "house_pack_info.gd")

KF = "kaykit-Furniture-Bits/addons/kaykit_furniture_bits/Assets/gltf/"
KR = "kaykit-Restaurant-Bits/addons/kaykit_restaurant_bits/Assets/gltf/"
KP = "kaykit-Prototype-Bits/addons/kaykit_prototype_bits/Assets/gltf/"
KK = "kenney_furniture/"   # Kenney Furniture Kit (CC0), glb files as mirrored by github.com/shorepine/kenney 3d/furniture
KC = "kaykit-City-Builder-Bits/addons/kaykit_city_builder_bits/Assets/gltf/"

# The house's own interior colours, added after the club's palette (indices >= 36): the colour
# of a set's pixel may land on them. Rooms are warmer and softer than the street.
HOUSE_COLOURS = [
    "f4ead5",  # cream wall
    "d8a373",  # oak
    "3b2f2a",  # espresso
    "e9b8a8",  # blush
    "a9c5a0",  # sage
    "e8b84a",  # mustard
    "6b4b7a",  # plum
    "7fb6d9",  # sky
    "c9a56b",  # cardboard / straw
    "dfe6ea",  # clinic white
    "4a8f87",  # deep teal
    "b5654a",  # terracotta
]
for _h in HOUSE_COLOURS:
    cm.PALETTE.append(tuple(int(_h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)))
    cm.PAL_LAB.append(cm.to_lab(cm.PALETTE[-1]))

CLUB_BLUE = (0x2a / 255.0, 0x54 / 255.0, 0xa3 / 255.0)
CLUB_DARK = (0x1e / 255.0, 0x3a / 255.0, 0x73 / 255.0)
DUST = (0.56, 0.52, 0.46)

# --- composing -----------------------------------------------------------------------


# The sets paint with a few hues (blue fabric, yellow cushions, orange kitchen, brown wood...);
# `remap` swaps a whole hue group for one colour of ours, keeping the set's own light and shade.
HUES = {"blue": (185, 260, 0.35), "yellow": (38, 60, 0.45), "orange": (19, 37, 0.45), "wood": (5, 19, 0.25),
        "teal": (140, 185, 0.35), "red": (350, 5, 0.5), "grey": (0, 360, 0.0)}


def hue_group(c):
    h, sat, v = colorsys.rgb_to_hsv(*c)
    h *= 360.0
    for name, (lo, hi, smin) in HUES.items():
        if name == "grey":
            continue
        inside = (lo <= h <= hi) if lo <= hi else (h >= lo or h <= hi)
        if inside and sat >= smin:
            return name, v
    return ("grey", v) if sat < 0.2 else (None, v)


def part(src, s=0.7, at=(0, 0, 0), yaw=0.0, pull=0.5, wear=0.0, allow=(), remap=None):
    """A set model inside a composed one. s: scale (a number or x/y/z), at: offset in metres
    (the model keeps its own origin: centred on x/z, standing on y = 0 after the scale),
    yaw in degrees, pull: toward the palette, wear: 0..1 worn out, remap: {hue group: colour}, see HUES."""
    if not isinstance(s, (tuple, list)):
        s = (s, s, s)
    return {"k": "model", "src": src, "s": s, "at": at, "yaw": yaw, "pull": pull, "wear": wear, "allow": allow, "remap": remap}


def box(size, at, col, yaw=0.0, wear=0.0):
    return {"k": "box", "size": size, "at": at, "col": col, "yaw": yaw, "wear": wear}


def cyl(r_top, r_bot, h, at, col, segs=8, wear=0.0):
    return {"k": "cyl", "rt": r_top, "rb": r_bot, "h": h, "at": at, "col": col, "segs": segs, "wear": wear}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def worn(c, w):
    """The colour of something old: dusty, a little darker."""
    if w <= 0.0:
        return c
    return tuple((c[k] + (DUST[k] - c[k]) * w * 0.55) * (1.0 - 0.16 * w) for k in range(3))


def box_tris(size, at, col, yaw):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    faces = [((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
             ((-1, 0, 0), [(-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)]),
             ((0, 1, 0), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
             ((0, -1, 0), [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
             ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
             ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)])]
    out = []
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def rot(p):
        return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)

    for n, quad in faces:
        pts = [rot((q[0] * sx, q[1] * sy, q[2] * sz)) for q in quad]
        pts = [(p[0] + at[0], p[1] + at[1], p[2] + at[2]) for p in pts]
        nn = rot(n)
        for tri in ((0, 1, 2), (0, 2, 3)):
            for i in tri:
                out.append((pts[i], nn, col))
    return out


def cyl_tris(rt, rb, h, at, col, segs):
    out = []
    y0, y1 = at[1] - h / 2, at[1] + h / 2
    ring = [(math.cos(2 * math.pi * i / segs), math.sin(2 * math.pi * i / segs)) for i in range(segs + 1)]
    slope = (rb - rt) / h if h else 0.0
    for i in range(segs):
        a, b = ring[i], ring[i + 1]
        mid = (a[0] + b[0], a[1] + b[1])
        ln = math.hypot(*mid) or 1.0
        n = (mid[0] / ln, slope * 0.5, mid[1] / ln)
        nl = math.sqrt(sum(x * x for x in n))
        n = tuple(x / nl for x in n)
        p00 = (at[0] + a[0] * rb, y0, at[2] + a[1] * rb)
        p01 = (at[0] + b[0] * rb, y0, at[2] + b[1] * rb)
        p10 = (at[0] + a[0] * rt, y1, at[2] + a[1] * rt)
        p11 = (at[0] + b[0] * rt, y1, at[2] + b[1] * rt)
        for p in (p00, p10, p11, p00, p11, p01):
            out.append((p, n, col))
        if rt > 0.001:
            for p in ((at[0], y1, at[2]), p11, p10):
                out.append((p, (0, 1, 0), col))
        for p in ((at[0], y0, at[2]), p00, p01):
            out.append((p, (0, -1, 0), col))
    return out


def model_tris(src_root, p):
    path = os.path.join(src_root, p["src"])
    g = cm.Gltf(path)
    tris = cm.flatten(g)
    # the model's own origin: centred on x/z, standing on y = 0 (like club_models.bake)
    lo = [min(t[0][k] for t in tris) for k in range(3)]
    hi = [max(t[0][k] for t in tris) for k in range(3)]
    cx, cz = (lo[0] + hi[0]) * 0.5, (lo[2] + hi[2]) * 0.5
    sx, sy, sz = p["s"]
    c, s = math.cos(math.radians(p["yaw"])), math.sin(math.radians(p["yaw"]))
    cache = {}
    out = []
    for pos, n, col in tris:
        key = tuple(round(x, 3) for x in col)
        if key not in cache:
            grp, v = hue_group(col)
            if p["remap"] and grp in p["remap"]:
                tgt = p["remap"][grp]
                if tgt == CLUB_BLUE:
                    cc = CLUB_BLUE if v >= 0.75 else CLUB_DARK   # the exact club blues: the game may swap them
                else:
                    k = max(0.55, min(1.2, v / 0.86))
                    cc = tuple(min(1.0, tgt[i] * k) for i in range(3))
            else:
                cc = cm.club_colour(col, p["pull"], p["allow"])
            cache[key] = worn(cc, p["wear"])
        q = ((pos[0] - cx) * sx, (pos[1] - lo[1]) * sy, (pos[2] - cz) * sz)
        q = (q[0] * c + q[2] * s, q[1], -q[0] * s + q[2] * c)
        q = (q[0] + p["at"][0], q[1] + p["at"][1], q[2] + p["at"][2])
        nn = (n[0] / sx, n[1] / sy, n[2] / sz)
        ln = math.sqrt(sum(x * x for x in nn)) or 1.0
        nn = (nn[0] / ln, nn[1] / ln, nn[2] / ln)
        nn = (nn[0] * c + nn[2] * s, nn[1], -nn[0] * s + nn[2] * c)
        out.append((q, nn, cache[key]))
    return out


_SIZES = {}


def src_size(src_root, rel):
    """Raw (x, y, z) of a set model."""
    if rel not in _SIZES:
        tris = cm.flatten(cm.Gltf(os.path.join(src_root, rel)))
        lo = [min(t[0][k] for t in tris) for k in range(3)]
        hi = [max(t[0][k] for t in tris) for k in range(3)]
        _SIZES[rel] = tuple(hi[k] - lo[k] for k in range(3))
    return _SIZES[rel]


def row(items, x0=0.0, z=0.0):
    """Models side by side along +x (a kitchen run): items are (src, scale, extra dict); each
    stands on y = 0 unless extra says `y`; returns parts; the row's left edge is x0."""
    out, x = [], x0
    for src, sc, extra in items:
        if not isinstance(sc, (tuple, list)):
            sc = (sc, sc, sc)
        w = src_size(SRC_ROOT, src)[0] * sc[0]
        kw = dict(extra)
        y = kw.pop("y", 0.0)
        out.append(part(src, sc, (x + w / 2, y, z + kw.pop("dz", 0.0)), **kw))
        x += w
    return out


def compose(src_root, parts, name=""):
    tris = []
    for p in parts:
        if p["k"] == "model":
            tris += model_tris(src_root, p)
        elif p["k"] == "box":
            tris += box_tris(p["size"], p["at"], worn(p["col"], p["wear"]), p["yaw"])
        else:
            tris += cyl_tris(p["rt"], p["rb"], p["h"], p["at"], worn(p["col"], p["wear"]), p["segs"])
    lo = [min(t[0][k] for t in tris) for k in range(3)]
    hi = [max(t[0][k] for t in tris) for k in range(3)]
    cx, cz = (lo[0] + hi[0]) * 0.5, (lo[2] + hi[2]) * 0.5
    verts, vlist, idx = {}, [], []
    for p, n, c in tris:
        q = (p[0] - cx, p[1] - lo[1], p[2] - cz)
        col = tuple(max(0, min(255, int(round(x * 255)))) for x in c)
        key = (tuple(round(x, 4) for x in q), tuple(round(x, 3) for x in n), col)
        i = verts.get(key)
        if i is None:
            i = len(vlist)
            verts[key] = i
            vlist.append((q, n, col))
        idx.append(i)
    # drop triangles that collapsed (two corners on one vertex)
    good = []
    for k in range(0, len(idx), 3):
        a, b, c = idx[k:k + 3]
        if a != b and b != c and a != c:
            good += [a, b, c]
    size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    return vlist, good, size


# --- the picks -------------------------------------------------------------------------
# id -> list of parts. Levels: _1 worn out, _2 plain, _3 good, _4 premium. Metres.
# Sizes below are for the sets' native unit (x1.5 a metre): s ~0.62-0.7 for furniture.

def picks():
    """id -> parts. Levels: _1 worn out, _2 plain, _3 good, _4 premium. Metres, front +z."""
    OAK, WOODL, WOODD = rgb("d8a373"), rgb("c08a55"), rgb("6b4a32")
    CREAM, SAGE, MUSTARD, PLUM = rgb("f4ead5"), rgb("a9c5a0"), rgb("e8b84a"), rgb("6b4b7a")
    TEAL, SKY, BLUSH, TERRA = rgb("4a8f87"), rgb("7fb6d9"), rgb("e9b8a8"), rgb("b5654a")
    GOLD, WHITE, GREY, METAL, METALD = rgb("ffd642"), rgb("f2f0ea"), rgb("9e968a"), rgb("b9bec4"), rgb("25272b")
    RUST, NAVY, STEEL, CLINIC = rgb("8c4a2a"), rgb("1e2a44"), rgb("6b7f94"), rgb("dfe6ea")
    DUSTY = (0.60, 0.55, 0.48)
    P = {}
    if os.environ.get("RAW"):   # a look at the sets themselves (gallery): RAW=1 python3 tools/academy_models.py SRC
        import glob
        for pre, sub in (("f_", KF), ("r_", KR), ("p_", KP), ("c_", KC)):
            for f in sorted(glob.glob(os.path.join(SRC_ROOT, sub, "*.gltf"))):
                n = os.path.basename(f)[:-5]
                if pre == "r_" and n.startswith(("food", "crate_", "jar", "lid", "pan", "pot")):
                    continue
                P["raw_" + pre + n] = [part(sub + n + ".gltf", float(os.environ.get("RAW_S", "0.5")))]
        for f in sorted(glob.glob(os.path.join(SRC_ROOT, KK, "*.glb"))):
            n = os.path.basename(f)[:-4]
            P["raw_k_" + n] = [part(KK + n + ".glb", 1.0)]
        return P
    F = lambda n: KF + n + ".gltf"   # noqa: E731
    R = lambda n: KR + n + ".gltf"   # noqa: E731
    T = lambda n: KP + n + ".gltf"   # noqa: E731

    # --- beds (the head toward -z) ------------------------------------------------------
    P["bed_1"] = [part(T("Pallet_Small"), (0.5, 0.45, 0.95), (0, 0, 0), wear=0.8),
                  box((0.92, 0.12, 1.9), (0, 0.29, 0), CREAM, wear=0.95),
                  box((0.94, 0.05, 0.95), (0.0, 0.37, 0.4), (0.45, 0.5, 0.42), wear=0.6),
                  box((0.5, 0.08, 0.3), (0, 0.39, -0.7), GREY, yaw=4, wear=0.7)]
    P["bed_2"] = [part(F("bed_single_A"), 0.62, wear=0.25, remap={"blue": SAGE, "wood": WOODL})]
    P["bed_3"] = [part(F("bed_single_B"), 0.66, remap={"blue": CLUB_BLUE, "wood": OAK}),
                  part(F("pillow_A"), 0.5, (0.12, 0.55, -0.75), yaw=8, remap={"yellow": MUSTARD})]
    P["bed_4"] = [part(F("bed_double_B"), (0.4, 0.68, 0.62), remap={"blue": PLUM, "wood": WOODD}),
                  part(F("pillow_B"), 0.55, (-0.25, 0.62, -0.7), yaw=-6, remap={"blue": GOLD}),
                  part(F("pillow_B"), 0.55, (0.28, 0.62, -0.72), yaw=7, remap={"blue": GOLD}),
                  box((1.36, 0.07, 0.07), (0, 1.12, -0.93), GOLD)]
    P["bunk_2"] = [part(F("bed_single_A"), 0.58, (0, 0.12, 0), wear=0.2, remap={"blue": SKY, "wood": WOODL}),
                   part(F("bed_single_A"), 0.58, (0, 1.1, 0), wear=0.2, remap={"blue": SAGE, "wood": WOODL})]
    for x in (-0.5, 0.5):
        for z in (-0.88, 0.88):
            P["bunk_2"].append(box((0.07, 1.9, 0.07), (x, 0.95, z), WOODD))
    P["bunk_2"].append(box((0.06, 0.9, 0.06), (0.52, 0.55, 0.0), WOODD))

    P["nightstand_1"] = [part(T("Box_C"), 0.65, wear=0.6)]
    P["nightstand_2"] = [part(F("cabinet_small"), 0.55, remap={"wood": WOODL})]
    P["nightstand_3"] = [part(F("cabinet_small_decorated"), 0.55, remap={"wood": OAK})]

    # --- sofas, armchairs -----------------------------------------------------------------
    P["sofa_1"] = [part(F("couch"), (0.62, 0.55, 0.62), wear=0.9, remap={"blue": (0.55, 0.45, 0.35)}),
                   box((0.5, 0.05, 0.4), (0.4, 0.62, 0.0), TERRA, yaw=10, wear=0.6)]
    P["sofa_2"] = [part(F("couch"), 0.66, wear=0.15, remap={"blue": SAGE})]
    P["sofa_3"] = [part(F("couch_pillows"), 0.68, remap={"yellow": CLUB_BLUE, "blue": MUSTARD, "orange": TERRA})]
    P["sofa_4"] = [part(F("couch_pillows"), 0.7, remap={"yellow": PLUM, "blue": GOLD, "orange": GOLD}),
                   part(F("chair_stool"), (0.5, 0.5, 0.5), (0, 0, 1.2), remap={"blue": PLUM, "wood": WOODD})]
    P["armchair_2"] = [part(F("armchair"), 0.62, wear=0.2, remap={"blue": SAGE})]
    P["armchair_3"] = [part(F("armchair_pillows"), 0.64, remap={"yellow": CLUB_BLUE, "blue": MUSTARD, "orange": TERRA})]
    P["armchair_4"] = [part(F("armchair"), 0.66, remap={"blue": PLUM})]

    # --- dining ---------------------------------------------------------------------------
    P["table_1"] = [part(T("table_medium_long"), (0.7, 0.72, 0.8), wear=0.85, remap={"blue": (0.72, 0.58, 0.42), "grey": (0.6, 0.5, 0.4)})]
    P["table_2"] = [part(F("table_medium_long"), (0.72, 0.72, 0.62), remap={"wood": WOODL})]
    P["table_3"] = [part(R("kitchentable_A_large"), (0.72, 0.74, 0.6), remap={"orange": OAK, "blue": OAK, "grey": WOODL})]
    P["table_4"] = [part(F("table_medium_long"), (0.8, 0.74, 0.68), remap={"wood": WOODD}),
                    box((2.0, 0.025, 1.0), (0, 0.745, 0), CREAM), box((0.4, 0.03, 1.02), (0, 0.76, 0), CLUB_BLUE),
                    box((2.0, 0.22, 0.02), (0, 0.63, 0.5), CREAM), box((2.0, 0.22, 0.02), (0, 0.63, -0.5), CREAM),
                    part(F("cactus_small_A"), 0.45, (0, 0.76, 0))]
    P["chair_1"] = [part(T("Box_A"), (0.8, 0.7, 0.8), wear=0.7)]

    # --- kitchens: a run along the back wall (counters 1 m wide, 0.9 high, 0.7 deep) --------
    CK = (0.5, 0.9, 0.34)
    CT = (0.55, 0.9, 0.4)
    FR = (0.4, 0.68, 0.3)
    SINK = [box((0.6, 0.02, 0.4), (0, 0.925, 0.0), METAL), cyl(0.015, 0.015, 0.3, (0, 1.07, -0.2), METAL, 4), box((0.03, 0.03, 0.14), (0, 1.22, -0.13), METAL)]

    def with_sink(parts, x):
        for q in SINK:
            q = dict(q)
            q["at"] = (q["at"][0] + x, q["at"][1], q["at"][2])
            parts.append(q)
        return parts

    P["kitchen_2"] = row([(R("fridge_B"), FR, {"remap": {"teal": SAGE}}),
                          (R("kitchencounter_straight_A"), CK, {"remap": {"orange": WOODL}}),
                          (R("kitchencounter_straight_B"), CK, {"remap": {"orange": WOODL}}),
                          (R("kitchencounter_straight_A"), CK, {"remap": {"orange": WOODL}})])
    with_sink(P["kitchen_2"], 2.3)
    P["kitchen_2"].append(part(R("stove_single_countertop"), CT, (3.3, 0.9, 0.0), remap={"orange": WOODL}))
    P["kitchen_3"] = row([(R("fridge_A"), FR, {"remap": {"teal": CLUB_BLUE}}),
                          (R("kitchencounter_straight_A_backsplash"), CK, {"remap": {"orange": OAK}}),
                          (R("kitchencounter_straight_B_backsplash"), CK, {"remap": {"orange": OAK}}),
                          (R("kitchencounter_straight_A_backsplash"), CK, {"remap": {"orange": OAK}}),
                          (R("kitchencounter_straight_B_backsplash"), CK, {"remap": {"orange": OAK}})])
    with_sink(P["kitchen_3"], 2.3)
    P["kitchen_3"].append(part(R("stove_single_countertop"), CT, (4.3, 0.9, 0.0), remap={"orange": OAK}))
    P["kitchen_3"].append(part(R("extractorhood"), (0.5, 0.5, 0.3), (4.3, 1.5, -0.1), remap={"orange": OAK}))
    P["kitchen_island_3"] = [part(R("kitchentable_A_large"), (0.7, 0.9, 0.5), remap={"orange": OAK, "blue": OAK, "grey": WOODL}),
                             part(R("plate"), 0.4, (-0.4, 0.9, 0.0)), part(R("bowl"), 0.4, (0.2, 0.9, 0.1)),
                             part(R("cuttingboard"), 0.5, (0.7, 0.9, -0.1))]
    P["kitchen_4"] = row([(R("fridge_A"), (0.45, 0.7, 0.32), {"remap": {"teal": WHITE}}),
                          (R("kitchencabinet"), (0.5, 0.45, 0.34), {"remap": {"orange": WOODD}}),
                          (R("kitchencounter_straight_B_backsplash"), CK, {"remap": {"orange": WOODD}}),
                          (R("kitchencounter_straight_A_backsplash"), CK, {"remap": {"orange": WOODD}}),
                          (R("kitchencounter_straight_B_backsplash"), CK, {"remap": {"orange": WOODD}})])
    with_sink(P["kitchen_4"], 2.3)
    P["kitchen_4"].append(part(R("stove_multi_countertop"), (0.55, 0.9, 0.4), (4.4, 0.9, 0.0), remap={"orange": WOODD}))
    P["kitchen_4"].append(part(R("extractorhood"), (0.55, 0.55, 0.3), (4.4, 1.5, -0.1), remap={"orange": GOLD}))
    P["kitchen_4"].append(box((4.3, 0.04, 0.72), (2.45, 0.92, 0.0), rgb("dfe6ea")))
    P["dishes_2"] = [part(R("plate"), 0.45, (-0.3, 0, 0.1)), part(R("plate_small"), 0.4, (0.1, 0, 0.1)), part(R("pot_A"), 0.35, (0.3, 0, -0.2))]

    # --- the coach's desks ------------------------------------------------------------------
    P["desk_1"] = [box((1.5, 0.07, 0.75), (0, 0.78, 0), (0.75, 0.62, 0.45), wear=0.8),
                   part(T("Box_C"), (0.8, 1.4, 0.8), (-0.52, 0, 0.0), wear=0.8), part(T("Box_C"), (0.8, 1.4, 0.8), (0.52, 0, 0.0), wear=0.8)]
    P["desk_2"] = [part(F("table_medium_long"), (0.62, 0.74, 0.5), remap={"wood": WOODL}),
                   box((0.5, 0.04, 0.34), (0.1, 0.76, 0.0), METALD), box((0.46, 0.3, 0.03), (0.1, 0.93, -0.12), METALD), box((0.42, 0.26, 0.01), (0.1, 0.93, -0.1), (0.5, 0.75, 0.85)),
                   part(F("book_set"), 0.5, (-0.5, 0.74, 0.0))]
    P["desk_3"] = [part(F("table_medium_long"), (0.7, 0.74, 0.55), remap={"wood": OAK}),
                   box((0.5, 0.04, 0.34), (0.1, 0.76, 0.0), METALD), box((0.5, 0.32, 0.03), (0.1, 0.94, -0.14), METALD), box((0.45, 0.27, 0.01), (0.1, 0.94, -0.12), (0.5, 0.75, 0.85)),
                   part(F("lamp_table"), 0.45, (-0.55, 0.74, -0.15)), part(F("book_set"), 0.5, (-0.3, 0.74, 0.18)),
                   box((0.2, 0.12, 0.28), (0.62, 0.8, 0.0), CREAM)]
    P["desk_4"] = [part(F("table_medium_long"), (0.9, 0.76, 0.62), remap={"wood": WOODD}),
                   box((1.9, 0.03, 0.85), (0, 0.775, 0), rgb("3b2f2a")),
                   box((0.5, 0.3, 0.03), (-0.3, 0.95, -0.2), METALD), box((0.46, 0.26, 0.01), (-0.3, 0.95, -0.18), (0.5, 0.75, 0.85)),
                   box((0.5, 0.3, 0.03), (0.35, 0.95, -0.2), METALD), box((0.46, 0.26, 0.01), (0.35, 0.95, -0.18), (0.5, 0.75, 0.85)),
                   box((0.5, 0.03, 0.2), (0.0, 0.8, 0.1), METALD), part(F("lamp_table"), 0.5, (-0.85, 0.775, -0.2), remap={"wood": GOLD}),
                   cyl(0.07, 0.09, 0.2, (0.85, 0.89, 0.15), GOLD), box((0.34, 0.05, 0.2), (0.85, 0.8, 0.15), WOODD)]

    # --- bookcase, trophy cabinet, rugs, lamps, frames, plants, doors ----------------------------
    P["bookcase_4"] = [box((1.5, 2.0, 0.04), (0, 1.0, -0.15), WOODD), box((0.05, 2.0, 0.34), (-0.75, 1.0, 0.0), WOODD), box((0.05, 2.0, 0.34), (0.75, 1.0, 0.0), WOODD),
                       box((1.55, 0.05, 0.36), (0, 2.02, 0.0), WOODD)]
    for k in range(5):
        P["bookcase_4"].append(box((1.45, 0.04, 0.32), (0, 0.04 + k * 0.45, 0.0), WOODL))
    for k, c in enumerate([rgb("d9473b"), rgb("2a54a3"), rgb("e8b84a"), rgb("4a8f87"), rgb("f2f0ea")]):
        P["bookcase_4"].append(part(F("book_set"), (0.7, 0.55, 0.7), (-0.45 + (k % 2) * 0.8, 0.06 + k * 0.45 * (1 if k < 4 else 0.9), 0.0)))
    P["rug_a"] = [part(F("rug_oval_A"), (0.5, 1.0, 0.5), remap={"blue": CLUB_BLUE, "yellow": MUSTARD})]
    P["rug_b"] = [part(F("rug_rectangle_stripes_A"), (0.5, 1.0, 0.5), remap={"blue": CLUB_BLUE, "yellow": CREAM})]
    P["rug_c"] = [part(F("rug_rectangle_B"), (0.5, 1.0, 0.5), remap={"blue": PLUM, "yellow": GOLD})]
    P["lamp_table"] = [part(F("lamp_table"), 0.45, remap={"wood": WOODL})]
    P["lamp_standing"] = [part(F("lamp_standing"), 0.6)]
    P["frame_s"] = [part(F("pictureframe_small_A"), 0.8)]
    P["frame_m"] = [part(F("pictureframe_medium"), 0.9)]
    P["frame_l"] = [part(F("pictureframe_large_B"), 0.8)]
    P["plant_s"] = [part(F("cactus_small_A"), 0.5)]
    P["plant_m"] = [part(F("cactus_medium_A"), 0.6)]
    P["door_a"] = [part(T("Door_A"), (0.68, 0.7, 0.7), remap={"blue": WOODL, "teal": WOODL})]
    P["door_b"] = [part(T("Door_B"), (0.68, 0.7, 0.7))]
    # --- Kenney Furniture Kit (CC0): what KayKit has not (the sets' native unit is ~0.5 of a metre) ---
    K = lambda n: KK + n + ".glb"   # noqa: E731
    P["chair_2"] = [part(K("chair"), 2.1, wear=0.15)]
    P["chair_3"] = [part(K("chairCushion"), 2.1, remap={"blue": CLUB_BLUE, "red": CLUB_BLUE, "teal": CLUB_BLUE})]
    P["chair_4"] = [part(K("chairCushion"), 2.2, remap={"blue": PLUM, "red": PLUM, "teal": PLUM, "wood": WOODD}),
                    box((0.06, 0.08, 0.06), (-0.2, 0.04, -0.2), GOLD), box((0.06, 0.08, 0.06), (0.2, 0.04, -0.2), GOLD),
                    box((0.06, 0.08, 0.06), (-0.2, 0.04, 0.2), GOLD), box((0.06, 0.08, 0.06), (0.2, 0.04, 0.2), GOLD)]
    P["tv_1"] = [part(K("cabinetTelevision"), 1.6, wear=0.8), part(K("televisionVintage"), 2.4, (0, 0.5, 0.0), wear=0.7),
                 part(K("televisionAntenna"), 2.4, (0.0, 1.14, -0.08), wear=0.6)]
    P["console_3"] = [part(K("cabinetTelevision"), (2.1, 1.7, 1.7), wear=0.0, remap={"wood": OAK}), part(K("televisionModern"), 2.0, (0, 0.52, -0.02)),
                      box((0.3, 0.05, 0.24), (-0.5, 0.55, 0.05), WHITE), box((0.16, 0.04, 0.1), (0.4, 0.54, 0.1), CLUB_BLUE, yaw=18)]
    P["speaker_5"] = [part(K("speaker"), 2.6, (-0.45, 0, 0.0)), part(K("speaker"), 2.6, (0.45, 0, 0.0)), box((0.7, 0.5, 0.5), (0.0, 0.25, 0.5), METALD)]
    P["chair_office_1"] = [part(K("chairDesk"), 1.7, wear=0.8)]
    P["fridge_1"] = [part(K("kitchenFridge"), (1.7, 1.6, 1.7), wear=0.85)]
    P["library_4"] = [part(K("bookcaseClosedWide"), (3.0, 2.6, 1.4), remap={"wood": WOODD}), part(K("bookcaseOpen"), (1.6, 2.6, 1.4), (1.6, 0, 0.0)),
                      part(K("books"), 2.0, (-0.9, 0.0, 0.0))]
    P["bunk_1"] = [part(K("bedBunk"), (1.8, 2.0, 1.8), wear=0.4)]
    P["coffee_2"] = [part(K("kitchenCoffeeMachine"), 1.8)]
    P["radio_1"] = [part(K("radio"), 1.8, wear=0.6)]
    P["crate_1"] = [part(T("Box_B"), 1.0, wear=0.6)]
    P["barrel_1"] = [part(T("Barrel_A"), 0.6, wear=0.7)]
    return P


def write_glb_quantized(models, out):
    """Like club_models.write_glb, but normals are normalised int8 (KHR_mesh_quantization):
    20 bytes a vertex instead of 28, ~25% off the pack. Positions stay float32, so a loader
    that only takes the meshes (HousePack) needs nothing else."""
    bin_ = bytearray()
    j = {"asset": {"version": "2.0", "generator": "tennisisi tools/academy_models.py"},
         "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [],
         "bufferViews": [], "buffers": [],
         "materials": [{"name": "academy_props", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.8}}]}

    def view(data, target, stride=None):
        while len(bin_) % 4:
            bin_.append(0)
        off = len(bin_)
        bin_.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target}
        if stride:
            v["byteStride"] = stride
        j["bufferViews"].append(v)
        return len(j["bufferViews"]) - 1

    def acc(bv, ctype, count, typ, mn=None, mx=None, normalized=False):
        a = {"bufferView": bv, "componentType": ctype, "count": count, "type": typ}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        if normalized:
            a["normalized"] = True
        j["accessors"].append(a)
        return len(j["accessors"]) - 1

    def sb(x):
        return max(-127, min(127, int(round(x * 127))))

    for name, (verts, idx) in models.items():
        pos = b"".join(struct.pack("<3f", *v[0]) for v in verts)
        nrm = b"".join(struct.pack("<4b", sb(v[1][0]), sb(v[1][1]), sb(v[1][2]), 0) for v in verts)
        col = b"".join(struct.pack("<4B", v[2][0], v[2][1], v[2][2], 255) for v in verts)
        ind = struct.pack("<%dH" % len(idx), *idx)
        mn = [min(v[0][k] for v in verts) for k in range(3)]
        mx = [max(v[0][k] for v in verts) for k in range(3)]
        a_p = acc(view(pos, 34962), 5126, len(verts), "VEC3", mn, mx)
        a_n = acc(view(nrm, 34962, 4), 5120, len(verts), "VEC3", normalized=True)
        a_c = acc(view(col, 34962), 5121, len(verts), "VEC4", normalized=True)
        a_i = acc(view(ind, 34963), 5123, len(idx), "SCALAR")
        j["meshes"].append({"name": name, "primitives": [{"attributes": {"POSITION": a_p, "NORMAL": a_n, "COLOR_0": a_c}, "indices": a_i, "material": 0}]})
        j["nodes"].append({"name": name, "mesh": len(j["meshes"]) - 1})
        j["scenes"][0]["nodes"].append(len(j["nodes"]) - 1)
    while len(bin_) % 4:
        bin_.append(0)
    j["buffers"].append({"byteLength": len(bin_)})
    import json
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
    global SRC_ROOT
    SRC_ROOT = src
    info = "--info" in sys.argv
    models, dims = {}, {}
    total = 0
    for name, parts in picks().items():
        verts, idx, size = compose(src, parts, name)
        models[name] = (verts, idx)
        dims[name] = size
        total += len(idx) // 3
        if info:
            print("%-22s %5d tris %5d verts   %.2f x %.2f x %.2f" % (name, len(idx) // 3, len(verts), size[0], size[1], size[2]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    (write_glb_quantized if "--plain" not in sys.argv else cm.write_glb)(models, OUT)
    import gzip
    import hashlib
    raw = open(OUT, "rb").read()
    ver = hashlib.sha256(raw).hexdigest()[:10]
    os.makedirs(os.path.dirname(INFO), exist_ok=True)
    with open(INFO, "w", newline="\n") as f:
        f.write("class_name HousePackInfo\n## Written by tools/academy_models.py: which pack the game asks the page for\n")
        f.write("## (models/academy_props.<VERSION>.glb), the ids in it and each one's size in metres (x, y, z).\n\n")
        f.write('const VERSION := "%s"\n' % ver)
        f.write("const IDS := [%s]\n" % ", ".join('"%s"' % k for k in models))
        f.write("const SIZES := {\n")
        for k, d in dims.items():
            f.write('\t"%s": Vector3(%.2f, %.2f, %.2f),\n' % (k, d[0], d[1], d[2]))
        f.write("}\n")
    print("%d models, %d triangles -> %s (%.0f KB, %.0f KB gzip)" % (len(models), total, OUT, len(raw) / 1024, len(gzip.compress(raw, 9)) / 1024))


if __name__ == "__main__":
    main()
