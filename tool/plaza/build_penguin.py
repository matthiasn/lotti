"""Build Plaza's original, smooth-skinned penguin. Standard library only.

Run: python3 tool/plaza/build_penguin.py
The GLB is a shipped model, not a review screenshot. Colours are assigned from
Lotti's tokens on import. Smooth unions remove the intersecting-ball silhouette;
the retained skeleton lets animation deform the neck, flippers and short legs.
"""

import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# name, parent joint, absolute rest position
BONES = [
    ("pelvis", None, (0, 0.60, 0)),
    ("spine", 0, (0, 1.05, 0)),
    ("head", 1, (0, 1.70, 0.025)),
    ("left-flipper", 1, (-0.50, 1.44, 0)),
    ("left-flipper-tip", 3, (-0.72, 1.04, 0)),
    ("right-flipper", 1, (0.50, 1.44, 0)),
    ("right-flipper-tip", 5, (0.72, 1.04, 0)),
    ("left-hip", 0, (-0.27, 0.60, 0)),
    ("left-knee", 7, (-0.27, 0.34, 0.18)),
    ("left-ankle", 8, (-0.27, 0.095, 0)),
    ("right-hip", 0, (0.27, 0.60, 0)),
    ("right-knee", 10, (0.27, 0.34, 0.18)),
    ("right-ankle", 11, (0.27, 0.095, 0)),
]
# Continuous egg-shaped torso, short neck and cap; no separate belly sphere.
SHAPES = [
    ((0, 1.00, 0), (0.58, 0.79, 0.45), 1),
    ((0, 0.62, -0.025), (0.48, 0.36, 0.38), 0),
    ((0, 1.53, -0.025), (0.38, 0.40, 0.33), 1),
    ((0, 1.91, 0.025), (0.43, 0.43, 0.38), 2),
    ((0, 0.47, -0.40), (0.23, 0.12, 0.21), 0),
]
for side, flipper, tip, hip, knee, ankle in [
    (-1, 3, 4, 7, 8, 9),
    (1, 5, 6, 10, 11, 12),
]:
    SHAPES += [
        ((side * 0.56, 1.40, 0), (0.15, 0.23, 0.09), flipper),
        ((side * 0.68, 1.15, 0), (0.14, 0.34, 0.075), flipper),
        ((side * 0.79, 0.91, 0.025), (0.082, 0.18, 0.055), tip),
        ((side * 0.27, 0.43, 0.045), (0.17, 0.24, 0.17), hip),
        ((side * 0.27, 0.23, 0.065), (0.105, 0.15, 0.115), knee),
        ((side * 0.27, 0.082, 0.13), (0.21, 0.082, 0.30), ankle),
    ]
    # Three low toe lobes are joined by the broad web of the foot.
    for toe in [-1, 0, 1]:
        SHAPES.append(
            (
                (side * 0.27 + toe * 0.14, 0.075, 0.36 + (0.03 if toe == 0 else 0)),
                (0.077, 0.075, 0.105),
                ankle,
            )
        )


def distances(p):
    x, y, z = p
    out = []
    for (cx, cy, cz), (rx, ry, rz), bone in SHAPES:
        ax, ay, az = (x - cx) / rx, (y - cy) / ry, (z - cz) / rz
        k0 = math.sqrt(ax * ax + ay * ay + az * az)
        k1 = math.sqrt((ax / rx) ** 2 + (ay / ry) ** 2 + (az / rz) ** 2)
        out.append((k0 * (k0 - 1) / k1 if k1 else -min(rx, ry, rz), bone))
    return out


def field(p):
    result = 100.0
    for value, _ in distances(p):
        h = max(0.09 - abs(result - value), 0) / 0.09
        result = min(result, value) - h * h * 0.09 * 0.25
    # Smooth unions inflate the webbed feet below the ellipsoids' own soles.
    # Intersect the finished surface with y >= 0 to retain a flat contact sole.
    return max(result, -p[1])


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
    # A sole must follow its ankle exactly. Blending the toes with the shin
    # bends the foot through the paving even when the IK contact is correct.
    if p[1] < 0.16 and abs(p[0]) > 0.10 and p[2] > -0.17:
        return [9 if p[0] < 0 else 12, 0, 0, 0], [1, 0, 0, 0]
    ds = distances(p)
    closest = min(v for v, _ in ds)
    scores = {}
    for value, bone in ds:
        scores[bone] = scores.get(bone, 0) + math.exp(-max(0, value - closest) / 0.055)
    best = sorted(scores.items(), key=lambda x: -x[1])[:4]
    total = sum(v for _, v in best)
    return [b for b, _ in best], [v / total for _, v in best]


# Marching tetrahedra with cached lattice edges: welded, smooth surface.
STEP = 0.055
xs = [-1.05 + i * STEP for i in range(40)]
ys = [-0.12 + i * STEP for i in range(47)]
zs = [-0.70 + i * STEP for i in range(25)]
nx, ny, nz = len(xs), len(ys), len(zs)
points = [(x, y, z) for x in xs for y in ys for z in zs]
values = [field(p) for p in points]
positions = []
normals = []
joints = []
skin_weights = []
body = []
belly = []
feet = []
cache = {}


def vertex(a, b):
    key = tuple(sorted((a, b)))
    if key in cache:
        return cache[key]
    t = values[a] / (values[a] - values[b])
    p = tuple(points[a][i] + (points[b][i] - points[a][i]) * t for i in range(3))
    idx = len(positions)
    cache[key] = idx
    positions.append(p)
    normals.append(normal(p))
    js, ws = weights(p)
    joints.append(js)
    skin_weights.append(ws)
    return idx


def triangle(a, b, c):
    pa, pb, pc = positions[a], positions[b], positions[c]
    u = [pb[i] - pa[i] for i in range(3)]
    v = [pc[i] - pa[i] for i in range(3)]
    cross = (
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
    )
    if sum(cross[i] * normals[a][i] for i in range(3)) < 0:
        b, c = c, b
    x, y, z = (sum(positions[k][i] for k in (a, b, c)) / 3 for i in range(3))
    bib = (x / 0.47) ** 2 + ((y - 1.05) / 0.68) ** 2 < 1
    face = any(
        ((x - side * 0.19) / 0.245) ** 2 + ((y - 1.94) / 0.32) ** 2 < 1
        for side in [-1, 1]
    )
    target = feet if y < 0.17 else belly if z > 0.12 and (bib or face) else body
    target.extend((a, b, c))


TETS = [
    (0, 5, 1, 6),
    (0, 1, 2, 6),
    (0, 2, 3, 6),
    (0, 3, 7, 6),
    (0, 7, 4, 6),
    (0, 4, 5, 6),
]
for ix in range(nx - 1):
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
                if len(inside) in (0, 4):
                    continue
                if len(inside) == 1 or len(inside) == 3:
                    lone, others = (
                        (inside[0], outside)
                        if len(inside) == 1
                        else (outside[0], inside)
                    )
                    triangle(*(vertex(lone, k) for k in others))
                else:
                    a, b = inside
                    c, d = outside
                    ac, ad, bc, bd = (
                        vertex(a, c),
                        vertex(a, d),
                        vertex(b, c),
                        vertex(b, d),
                    )
                    triangle(ac, ad, bc)
                    triangle(ad, bd, bc)


# The face uses shallow insets on the actual sculpted surface.
def front(x, y):
    lo, hi = 0.05, 1.15
    for _ in range(24):
        mid = (lo + hi) / 2
        if field((x, y, mid)) < 0:
            lo = mid
        else:
            hi = mid
    return hi


groups = {
    "body": body,
    "belly": belly,
    "eyes": [],
    "pupils": [],
    "glints": [],
    "beak": [],
    "feet": feet,
}


def ellipsoid(group, center, radii):
    start = len(positions)
    segments = 20
    rings = 12
    for row in range(rings + 1):
        lat = math.pi * row / rings
        for col in range(segments):
            angle = 2 * math.pi * col / segments
            unit = (
                math.sin(lat) * math.cos(angle),
                math.cos(lat),
                math.sin(lat) * math.sin(angle),
            )
            p = tuple(center[i] + unit[i] * radii[i] for i in range(3))
            n = [unit[i] / radii[i] for i in range(3)]
            length = math.sqrt(sum(v * v for v in n))
            positions.append(p)
            normals.append(tuple(v / length for v in n))
            joints.append([2, 0, 0, 0])
            skin_weights.append([1, 0, 0, 0])
    for row in range(rings):
        for col in range(segments):
            a = start + row * segments + col
            b = start + row * segments + (col + 1) % segments
            c = a + segments
            d = b + segments
            if row:
                groups[group].extend((a, b, c))
            if row < rings - 1:
                groups[group].extend((b, d, c))


for side in [-1, 1]:
    x = side * 0.18
    y = 2.025
    z = front(x, y)
    ellipsoid("eyes", (x, y, z + 0.004), (0.095, 0.112, 0.034))
    ellipsoid("pupils", (x, y - 0.008, z + 0.032), (0.061, 0.079, 0.02))
    ellipsoid("glints", (x - 0.02, y + 0.024, z + 0.050), (0.016, 0.019, 0.009))
# A short tapered bill with a closed seam, below the eyes.
ellipsoid("beak", (0, 1.825, 0.46), (0.19, 0.083, 0.255))
ellipsoid("beak", (0, 1.778, 0.46), (0.17, 0.042, 0.22))
ellipsoid("pupils", (0, 1.790, 0.49), (0.172, 0.007, 0.20))

blob = bytearray()
views = []
accessors = []


def accessor(rows, components, kind, fmt="f", component=5126, bounds=False):
    while len(blob) % 4:
        blob.append(0)
    offset = len(blob)
    flattened = [v for row in rows for v in row] if components > 1 else list(rows)
    blob.extend(struct.pack("<" + fmt * len(flattened), *flattened))
    view = len(views)
    views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(blob) - offset})
    a = {
        "bufferView": view,
        "componentType": component,
        "count": len(rows),
        "type": kind,
    }
    if bounds:
        a["min"] = [min(row[i] for row in rows) for i in range(components)]
        a["max"] = [max(row[i] for row in rows) for i in range(components)]
    accessors.append(a)
    return len(accessors) - 1


attributes = {
    "POSITION": accessor(positions, 3, "VEC3", bounds=True),
    "NORMAL": accessor(normals, 3, "VEC3"),
    "JOINTS_0": accessor(joints, 4, "VEC4", "H", 5123),
    "WEIGHTS_0": accessor(skin_weights, 4, "VEC4"),
}
nodes = [{"name": "penguin-model", "children": []}]
for name, parent, absolute in BONES:
    at = (
        absolute
        if parent is None
        else tuple(absolute[i] - BONES[parent][2][i] for i in range(3))
    )
    nodes.append({"name": name, "translation": at, "children": []})
    nodes[0 if parent is None else parent + 1]["children"].append(len(nodes) - 1)
matrices = []
for _, _, (x, y, z) in BONES:
    matrices.append((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1))
inverse = accessor(matrices, 16, "MAT4")
meshes = []
materials = []
for name, indices in groups.items():
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
    meshes.append(
        {
            "name": name,
            "primitives": [
                {
                    "attributes": attributes,
                    "indices": accessor(indices, 1, "SCALAR", "I", 5125),
                    "material": len(materials) - 1,
                }
            ],
        }
    )
    nodes.append({"name": name + "-surface", "mesh": len(meshes) - 1, "skin": 0})
    nodes[0]["children"].append(len(nodes) - 1)
while len(blob) % 4:
    blob.append(0)
doc = {
    "asset": {"version": "2.0", "generator": "Lotti original penguin sculpt"},
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
path = ROOT / "assets/plaza/penguin.glb"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_bytes(content)
print(
    f"{path}: {len(positions)} vertices, {sum(len(v) for v in groups.values())//3} triangles, {len(content)} bytes"
)
