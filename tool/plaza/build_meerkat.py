"""Build Plaza's smooth-skinned meerkat with four paws and a balancing tail.

Run: python3 tool/plaza/build_meerkat.py
The authored rest pose is upright. Four three-joint limbs support both the
scamper and lookout poses; the head counters torso pitch. Standard library only.
Colours come from the existing Plaza/design-system palettes on import.
"""

import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BONES = [
    ("pelvis", None, (0, 0.62, 0)),
    ("spine", 0, (0, 1.07, 0)),
    ("head", 1, (0, 1.58, 0.04)),
    ("left-shoulder", 1, (-0.23, 1.38, 0.04)),
    ("left-elbow", 3, (-0.30, 1.04, 0.10)),
    ("left-wrist", 4, (-0.29, 0.70, 0.14)),
    ("right-shoulder", 1, (0.23, 1.38, 0.04)),
    ("right-elbow", 6, (0.30, 1.04, 0.10)),
    ("right-wrist", 7, (0.29, 0.70, 0.14)),
    ("left-hip", 0, (-0.17, 0.62, 0)),
    ("left-knee", 9, (-0.18, 0.33, 0.16)),
    ("left-ankle", 10, (-0.19, 0.075, 0.04)),
    ("right-hip", 0, (0.17, 0.62, 0)),
    ("right-knee", 12, (0.18, 0.33, 0.16)),
    ("right-ankle", 13, (0.19, 0.075, 0.04)),
    ("tail-base", 0, (0, 0.60, -0.14)),
    ("tail-middle", 15, (0, 0.30, -0.70)),
    ("tail-tip", 16, (0, 0.06, -1.27)),
    ("left-gaze", 2, (-0.13, 1.86, 0.34)),
    ("right-gaze", 2, (0.13, 1.86, 0.34)),
]

SHAPES = [
    ((0, 0.65, 0), (0.24, 0.32, 0.22), 0),
    ((0, 1.05, 0.015), (0.25, 0.49, 0.23), 1),
    ((0, 1.51, 0.025), (0.175, 0.28, 0.17), 1),
    ((0, 1.82, 0.09), (0.33, 0.30, 0.27), 2),
    ((0, 1.72, 0.33), (0.19, 0.105, 0.19), 2),
    ((0, 1.735, 0.46), (0.075, 0.065, 0.115), 2),
]
for side, shoulder, elbow, wrist, hip, knee, ankle in [
    (-1, 3, 4, 5, 9, 10, 11),
    (1, 6, 7, 8, 12, 13, 14),
]:
    SHAPES += [
        ((side * 0.30, 1.99, 0.0), (0.09, 0.12, 0.075), 2),
        ((side * 0.14, 1.73, 0.22), (0.17, 0.14, 0.18), 2),
        ((side * 0.245, 1.27, 0.04), (0.095, 0.22, 0.095), shoulder),
        ((side * 0.295, 0.98, 0.105), (0.075, 0.25, 0.07), elbow),
        ((side * 0.29, 0.665, 0.20), (0.09, 0.04, 0.14), wrist),
        ((side * 0.17, 0.50, 0.02), (0.15, 0.235, 0.16), hip),
        ((side * 0.18, 0.23, 0.10), (0.075, 0.20, 0.085), knee),
        ((side * 0.19, 0.06, 0.12), (0.105, 0.06, 0.17), ankle),
    ]
for i in range(10):
    t = i / 9
    radius = 0.105 * (1 - t) + 0.021 * t
    SHAPES.append(
        (
            (0, 0.57 * (1 - t) ** 1.3 + 0.021, -0.17 - 1.18 * t),
            (radius, radius + 0.025 * (1 - t), 0.16),
            15 if t < 0.33 else 16 if t < 0.7 else 17,
        )
    )


def distances(p):
    result = []
    for center, radii, bone in SHAPES:
        q = [(p[i] - center[i]) / radii[i] for i in range(3)]
        a = math.sqrt(sum(v * v for v in q))
        b = math.sqrt(sum((q[i] / radii[i]) ** 2 for i in range(3)))
        result.append((a * (a - 1) / b if b else -min(radii), bone))
    return result


def field(p):
    value = 100.0
    for d, _ in distances(p):
        h = max(0.055 - abs(value - d), 0) / 0.055
        value = min(value, d) - h * h * 0.055 * 0.25
    return max(value, -p[1])


def normal(p):
    e = 0.001
    n = [
        field(tuple(p[j] + (e if j == i else 0) for j in range(3)))
        - field(tuple(p[j] - (e if j == i else 0) for j in range(3)))
        for i in range(3)
    ]
    length = math.sqrt(sum(v * v for v in n))
    return tuple(v / length for v in n)


def weights(p):
    ds = distances(p)
    nearest, closest_bone = min(ds)
    if (p[1] < 0.13 and closest_bone in (11, 14)) or closest_bone in (5, 8):
        return [closest_bone, 0, 0, 0], [1, 0, 0, 0]
    scores = {}
    for d, bone in ds:
        scores[bone] = scores.get(bone, 0) + math.exp(-max(0, d - nearest) / 0.04)
    best = sorted(scores.items(), key=lambda item: -item[1])[:4]
    total = sum(v for _, v in best)
    return [b for b, _ in best], [v / total for _, v in best]


positions, normals, joints, skin_weights = [], [], [], []
groups = {name: [] for name in ("fur", "belly", "mask", "eyes", "pupils", "lids")}
closed = {}


def add_vertex(p, n, bone=None):
    index = len(positions)
    positions.append(p)
    normals.append(n)
    js, ws = weights(p) if bone is None else ([bone, 0, 0, 0], [1, 0, 0, 0])
    joints.append(js)
    skin_weights.append(ws)
    return index


def triangle(a, b, c, surface=None):
    p, q, r = (positions[i] for i in (a, b, c))
    u, v = ([q[i] - p[i] for i in range(3)], [r[i] - p[i] for i in range(3)])
    cross = (
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
    )
    if sum(v * v for v in cross) < 1e-20:
        return
    if sum(cross[i] * sum(normals[k][i] for k in (a, b, c)) for i in range(3)) < 0:
        b, c = c, b
    if surface is None:
        x, y, z = (sum(positions[k][i] for k in (a, b, c)) / 3 for i in range(3))
        bib = z > 0.12 and abs(x) < 0.18 and 0.67 < y < 1.5
        muzzle = z > 0.27 and y < 1.8 and y > 1.61
        eye_mask = z > 0.27 and any(
            ((x - side * 0.13) / 0.108) ** 2 + ((y - 1.86) / 0.089) ** 2 < 1
            for side in (-1, 1)
        )
        ear = abs(x) > 0.25 and y > 1.96 and z > 0.015
        stripe = z < -0.17 and 0.76 < y < 1.40 and abs(math.sin(y * 20)) < 0.3
        surface = (
            "mask"
            if eye_mask or ear or z < -1.10 or stripe
            else "belly" if bib or muzzle else "fur"
        )
    groups[surface].extend((a, b, c))


STEP = 0.043
xs = [-0.59 + i * STEP for i in range(29)]
ys = [-0.055 + i * STEP for i in range(54)]
zs = [-1.57 + i * STEP for i in range(53)]
ny, nz = len(ys), len(zs)
points = [(x, y, z) for x in xs for y in ys for z in zs]
values = [field(p) for p in points]
cache = {}


def intersection(a, b):
    key = tuple(sorted((a, b)))
    if key not in cache:
        t = values[a] / (values[a] - values[b])
        p = tuple(points[a][i] + (points[b][i] - points[a][i]) * t for i in range(3))
        cache[key] = add_vertex(p, normal(p))
    return cache[key]


TETS = [
    (0, 5, 1, 6),
    (0, 1, 2, 6),
    (0, 2, 3, 6),
    (0, 3, 7, 6),
    (0, 7, 4, 6),
    (0, 4, 5, 6),
]
for ix in range(len(xs) - 1):
    for iy in range(ny - 1):
        for iz in range(nz - 1):
            base = (ix * ny + iy) * nz + iz
            cube = [
                base,
                base + ny * nz,
                base + ny * nz + nz,
                base + nz,
                base + 1,
                base + ny * nz + 1,
                base + ny * nz + nz + 1,
                base + nz + 1,
            ]
            if min(values[k] for k in cube) > 0 or max(values[k] for k in cube) < 0:
                continue
            for tet in TETS:
                inside = [cube[k] for k in tet if values[cube[k]] < 0]
                outside = [cube[k] for k in tet if values[cube[k]] >= 0]
                if len(inside) in (1, 3):
                    lone, others = (
                        (inside, outside) if len(inside) == 1 else (outside, inside)
                    )
                    triangle(*(intersection(lone[0], k) for k in others))
                elif len(inside) == 2:
                    a, b = inside
                    c, d = outside
                    ac, ad, bc, bd = (
                        intersection(i, j) for i, j in ((a, c), (a, d), (b, c), (b, d))
                    )
                    triangle(ac, ad, bc)
                    triangle(ad, bd, bc)


def ellipsoid(center, radii, bone, surface, rows=12, columns=20):
    start = len(positions)
    for row in range(rows + 1):
        phi = math.pi * row / rows
        for column in range(columns + 1):
            theta = 2 * math.pi * column / columns
            u = (
                math.sin(phi) * math.cos(theta),
                math.cos(phi),
                math.sin(phi) * math.sin(theta),
            )
            n = [u[i] / radii[i] for i in range(3)]
            length = math.sqrt(sum(v * v for v in n))
            add_vertex(
                tuple(center[i] + radii[i] * u[i] for i in range(3)),
                tuple(v / length for v in n),
                bone,
            )
    for row in range(rows):
        for column in range(columns):
            a = start + row * (columns + 1) + column
            b = a + columns + 1
            triangle(a, b, a + 1, surface)
            triangle(a + 1, b, b + 1, surface)


ellipsoid((0, 1.735, 0.555), (0.057, 0.039, 0.033), 2, "mask")
for side, gaze in [(-1, 18), (1, 19)]:
    x, y, z = side * 0.13, 1.86, 0.34
    ellipsoid((x, y, z), (0.065, 0.063, 0.013), 2, "eyes")
    ellipsoid((x, y - 0.003, z + 0.012), (0.044, 0.048, 0.006), gaze, "pupils")
    ellipsoid((x - 0.013, y + 0.016, z + 0.018), (0.008, 0.010, 0.003), gaze, "eyes")
    start = len(positions)
    columns, rows = 20, 7
    for row in range(rows + 1):
        v = max(0, (row - 1) / (rows - 1))
        for column in range(columns + 1):
            u = -1 + 2 * column / columns
            top = y + 0.066 * math.sqrt(max(0, 1 - u * u)) + 0.004
            lower = min(top - 0.003, y + 0.049)
            depth = z + 0.004 + 0.026 * math.sqrt(max(0, 1 - u * u))
            p = (x + 0.077 * u, top + (lower - top) * v, depth if row else z - 0.012)
            index = add_vertex(p, (0, 0, 1), 2)
            closed[index] = (p[0], top + (y - 0.073 - top) * v, p[2])
    for row in range(rows):
        for column in range(columns):
            a = start + row * (columns + 1) + column
            b = a + columns + 1
            triangle(a, b, a + 1, "lids")
            triangle(a + 1, b, b + 1, "lids")


def surface_normals(source):
    result = [[0.0, 0.0, 0.0] for _ in source]
    for indices in groups.values():
        for at in range(0, len(indices), 3):
            a, b, c = indices[at : at + 3]
            u = [source[b][j] - source[a][j] for j in range(3)]
            v = [source[c][j] - source[a][j] for j in range(3)]
            n = (
                u[1] * v[2] - u[2] * v[1],
                u[2] * v[0] - u[0] * v[2],
                u[0] * v[1] - u[1] * v[0],
            )
            for k in (a, b, c):
                for j in range(3):
                    result[k][j] += n[j]
    for i, n in enumerate(result):
        length = math.sqrt(sum(v * v for v in n))
        result[i] = tuple(v / length for v in n) if length else normals[i]
    return result


closed_positions = [closed.get(i, p) for i, p in enumerate(positions)]
closed_normals = surface_normals(closed_positions)
normals = surface_normals(positions)
blob, views, accessors = bytearray(), [], []


def accessor(rows, components, kind, fmt="f", component=5126, bounds=False):
    blob.extend(b"\0" * ((-len(blob)) % 4))
    offset = len(blob)
    flat = [v for row in rows for v in row] if components > 1 else list(rows)
    blob.extend(struct.pack("<" + fmt * len(flat), *flat))
    views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(blob) - offset})
    item = {
        "bufferView": len(views) - 1,
        "componentType": component,
        "count": len(rows),
        "type": kind,
    }
    if bounds:
        item.update(
            min=[min(row[i] for row in rows) for i in range(components)],
            max=[max(row[i] for row in rows) for i in range(components)],
        )
    accessors.append(item)
    return len(accessors) - 1


nodes = [{"name": "meerkat-model", "children": []}]
for name, parent, absolute in BONES:
    at = (
        absolute
        if parent is None
        else tuple(absolute[i] - BONES[parent][2][i] for i in range(3))
    )
    nodes.append({"name": name, "translation": at, "children": []})
    nodes[0 if parent is None else parent + 1]["children"].append(len(nodes) - 1)
inverse = accessor(
    [(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1) for _, _, (x, y, z) in BONES],
    16,
    "MAT4",
)
meshes, materials = [], []
for name, indices in groups.items():
    used = sorted(set(indices))
    remap = {old: new for new, old in enumerate(used)}
    attributes = {
        "POSITION": accessor([positions[i] for i in used], 3, "VEC3", bounds=True),
        "NORMAL": accessor([normals[i] for i in used], 3, "VEC3"),
        "JOINTS_0": accessor([joints[i] for i in used], 4, "VEC4", "H", 5123),
        "WEIGHTS_0": accessor([skin_weights[i] for i in used], 4, "VEC4"),
    }
    primitive = {
        "attributes": attributes,
        "indices": accessor([remap[i] for i in indices], 1, "SCALAR", "I", 5125),
        "material": len(materials),
    }
    mesh = {"name": name, "primitives": [primitive]}
    if name == "lids":
        primitive["targets"] = [
            {
                "POSITION": accessor(
                    [
                        tuple(
                            closed_positions[i][j] - positions[i][j] for j in range(3)
                        )
                        for i in used
                    ],
                    3,
                    "VEC3",
                    bounds=True,
                ),
                "NORMAL": accessor(
                    [
                        tuple(closed_normals[i][j] - normals[i][j] for j in range(3))
                        for i in used
                    ],
                    3,
                    "VEC3",
                ),
            }
        ]
        mesh.update(weights=[0], extras={"targetNames": ["blink"]})
    materials.append(
        {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [1, 1, 1, 1],
                "metallicFactor": 0,
                "roughnessFactor": 1,
            },
        }
    )
    meshes.append(mesh)
    nodes.append({"name": name + "-surface", "mesh": len(meshes) - 1, "skin": 0})
    nodes[0]["children"].append(len(nodes) - 1)
blob.extend(b"\0" * ((-len(blob)) % 4))
doc = {
    "asset": {"version": "2.0", "generator": "Lotti original meerkat sculpt"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": nodes,
    "meshes": meshes,
    "materials": materials,
    "skins": [
        {
            "joints": list(range(1, len(BONES) + 1)),
            "inverseBindMatrices": inverse,
            "skeleton": 1,
        }
    ],
    "accessors": accessors,
    "bufferViews": views,
    "buffers": [{"byteLength": len(blob)}],
}
metadata = json.dumps(doc, separators=(",", ":")).encode()
metadata += b" " * ((-len(metadata)) % 4)
content = (
    struct.pack("<III", 0x46546C67, 2, 28 + len(metadata) + len(blob))
    + struct.pack("<II", len(metadata), 0x4E4F534A)
    + metadata
    + struct.pack("<II", len(blob), 0x004E4942)
    + blob
)
path = ROOT / "assets/plaza/meerkat.glb"
path.write_bytes(content)
print(
    f"{path}: {len(positions)} vertices, {sum(len(v) for v in groups.values()) // 3} triangles, {len(content)} bytes"
)
