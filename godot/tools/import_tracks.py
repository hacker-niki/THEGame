"""Extract the five tracks from the THEGame Unity checkout using Python 3.

Usage: python3 tools/import_tracks.py /path/to/original/THEGame
Coordinates stay in Unity space (+Z forward). Box dimensions are full extents.
"""

import argparse
import json
import math
import re
from pathlib import Path


def field(document, name):
    match = re.search(rf"^  {name}: (.+)$", document, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing Unity field {name}")
    return match[1]


def documents(path):
    parts = re.split(r"^--- !u!(\d+) &(-?\d+)(?: stripped)?\n", path.read_text(), flags=re.MULTILINE)
    return {identifier: (kind, body) for kind, identifier, body in zip(parts[1::3], parts[2::3], parts[3::3])}


def transform_values(document):
    values = {}
    for key in ("m_LocalPosition", "m_LocalScale", "m_LocalRotation"):
        for axis, value in re.findall(r"([xyzw]): ([^,}]+)", field(document, key)):
            values[f"{key}.{axis}"] = float(value)
    return values


def packed_transform(values):
    position = [values[f"m_LocalPosition.{axis}"] for axis in "xyz"]
    scale = [values[f"m_LocalScale.{axis}"] for axis in "xyz"]
    x, y, z, w = [values[f"m_LocalRotation.{axis}"] for axis in "xyzw"]
    if abs(x) + abs(z) > 0.00001:
        raise ValueError("Track contains a non-horizontal rotation")
    yaw = round(math.degrees(2 * math.atan2(y, w)), 4)
    return [int(n) if n == int(n) else n for n in [*position, *scale, yaw]]


def tagged_transforms(scene):
    # Player is serialized into the scene; obstacles and the goal are prefab instances.
    tagged = {}
    for kind, body in scene.values():
        if kind != "1" or "  m_IsActive: 1\n" not in body:
            continue
        tag = field(body, "m_TagString")
        if tag in ("Player", "surface"):
            first_component = re.search(r"- component: \{fileID: (\d+)\}", body)[1]
            tagged[first_component] = tag
    return tagged


def model_registry(models):
    result = {}
    for name in ("box.prefab", "END.prefab", "bench.obj", "car3.obj", "trees2.obj"):
        guid = re.search(r"^guid: (\w+)", (models / (name + ".meta")).read_text(), re.MULTILINE)[1]
        defaults = {}
        if name.endswith(".prefab"):
            root = next(body for kind, body in documents(models / name).values() if kind == "4")
            defaults = transform_values(root)
        result[guid] = (Path(name).stem, defaults)
    return result


def extract_track(path, registry):
    scene = documents(path)
    tagged = tagged_transforms(scene)
    track = {"start": [], "finish": [], "roads": [], "obstacles": [], "scenery": []}
    for transform_id, tag in tagged.items():
        kind, body = scene[transform_id]
        if kind != "4":
            raise ValueError(f"Missing {tag} Transform in {path.name}")
        if field(body, "m_Father") != "{fileID: 0}":
            raise ValueError(f"{tag} is nested in {path.name}")
        spatial = packed_transform(transform_values(body))
        if tag == "Player":
            track["start"] = spatial[:3]
        else:
            track["roads"].append(spatial)

    for kind, body in scene.values():
        if kind != "1001":
            continue
        guid = re.search(r"guid: (\w+)", field(body, "m_SourcePrefab"))[1]
        if guid not in registry:
            continue
        name, defaults = registry[guid]
        changes = dict(re.findall(r"propertyPath: ([\w.]+)\n +value: ([^\n]*)", body))
        if changes.get("m_IsActive") == "0":
            continue
        if "m_TransformParent: {fileID: 0}" not in body:
            raise ValueError(f"{name} is nested in {path.name}")
        values = defaults | {key: float(value) for key, value in changes.items()
                             if key.startswith(("m_LocalPosition.", "m_LocalScale.", "m_LocalRotation."))}
        spatial = packed_transform(values)
        if name == "box":
            track["obstacles"].append(spatial)
        elif name == "END":
            track["finish"] = spatial[:3]
        else:
            track["scenery"].append([name, *spatial])

    if not all(track.values()):
        raise ValueError(f"Incomplete track in {path.name}")
    track["obstacles"].sort(key=lambda obstacle: (obstacle[2], obstacle[0]))
    track["scenery"].sort(key=lambda prop: prop[3])
    return track


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unity_project", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().parents[1] / "data" / "tracks.json")
    args = parser.parse_args()
    assets = args.unity_project / "Assets"
    registry = model_registry(assets / "models")
    tracks = [extract_track(assets / "Scenes" / f"Level{i}.unity", registry) for i in range(1, 6)]
    pretty = json.dumps(tracks, indent=2)
    # Keep one transform per line for editing and diffing the exported layout.
    pretty = re.sub(r"\[\s*([^\[\]{}]+?)\s*\]", lambda m: "[" + " ".join(m[1].split()) + "]", pretty)
    args.output.write_text(pretty + "\n")


if __name__ == "__main__":
    main()
