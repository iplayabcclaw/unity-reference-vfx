#!/usr/bin/env python3
"""Offline orthographic mesh preview. Requires numpy, Pillow and an authored shader adapter.

The adapter exports shade(uv, normal, vertex_color, time, material) -> (linear_rgb, alpha).
Triangle depth sorting approximates SrcAlpha / OneMinusSrcAlpha, not Unity rendering.
"""
import argparse
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


def render(scene, shade, *, width=660, height=520, pitch=45, yaw=0,
           time=0, center=None, span=None, samples=2):
    if min(width, height) < 1 or not 1 <= samples <= 4:
        raise ValueError("Positive image dimensions and 1..4 samples required")
    triangles, uvs, colors, materials = [], [], [], []
    for mesh in scene["meshes"]:
        vertices = np.asarray(mesh["vertices"], dtype=float)
        indices = np.asarray(mesh["triangles"], dtype=int)
        uv = np.asarray(mesh.get("uv", np.zeros((len(vertices), 2))), dtype=float)
        color = np.asarray(mesh.get("colors", np.ones((len(vertices), 4))), dtype=float)
        if (vertices.ndim != 2 or vertices.shape[1] != 3
                or indices.ndim != 2 or indices.shape[1] != 3
                or uv.shape != (len(vertices), 2) or color.shape != (len(vertices), 4)):
            raise ValueError("Expected Nx3 vertices, Mx3 triangles, Nx2 UV and Nx4 colors")
        if np.any(indices < 0) or np.any(indices >= len(vertices)):
            raise ValueError("Triangle index outside vertex array")
        if not all(np.isfinite(a).all() for a in (vertices, uv, color)):
            raise ValueError("Mesh contains non-finite data")
        triangles.extend(vertices[indices]); uvs.extend(uv[indices]); colors.extend(color[indices])
        materials.extend([mesh.get("material", 0)] * len(indices))
    if not triangles:
        raise ValueError("Scene has no triangles")
    triangles, uvs, colors = map(np.asarray, (triangles, uvs, colors))
    pitch, yaw = np.deg2rad([pitch, yaw])
    right = np.array([math.cos(yaw), 0, -math.sin(yaw)])
    up = np.array([-math.sin(pitch)*math.sin(yaw), math.cos(pitch),
                   -math.sin(pitch)*math.cos(yaw)])
    depth = np.cross(right, up)
    projected = np.stack([triangles @ right, triangles @ up, triangles @ depth], axis=-1)
    w, h = width*samples, height*samples
    if center is None:
        bounds = projected.reshape(-1, 3)
        mid = (bounds[:, :2].min(0) + bounds[:, :2].max(0)) / 2
    else:
        mid = np.array([np.dot(center, right), np.dot(center, up)])
    if span is None:
        distance = np.max(np.abs(projected[..., :2] - mid), axis=(0, 1)) * 2
        span = max(distance[0], distance[1]*w/h, .01) * 1.12
    if not np.isfinite(span) or span <= 0:
        raise ValueError("Camera span must be positive and finite")
    projected[..., 0] = (projected[..., 0]-mid[0])*w/span + w/2
    projected[..., 1] = h/2 - (projected[..., 1]-mid[1])*w/span
    background = np.asarray(scene.get("background", [.025, .028, .036]), dtype=float)
    if background.shape != (3,) or not np.isfinite(background).all():
        raise ValueError("Background must be a finite linear RGB triple")
    canvas = np.broadcast_to(background, (h, w, 3)).copy()
    for index in np.argsort(projected[..., 2].mean(axis=1), kind="stable"):
        triangle = projected[index]
        x0, y0 = np.maximum(0, np.floor(triangle[:, :2].min(0))).astype(int)
        x1, y1 = np.minimum([w-1, h-1], np.ceil(triangle[:, :2].max(0))).astype(int)
        if x1 < x0 or y1 < y0:
            continue
        x, y = np.meshgrid(np.arange(x0, x1+1)+.5, np.arange(y0, y1+1)+.5)
        ax, ay = triangle[0, :2]; bx, by = triangle[1, :2]; cx, cy = triangle[2, :2]
        denominator = (by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
        if abs(denominator) < 1e-10:
            continue
        a = ((by-cy)*(x-cx)+(cx-bx)*(y-cy))/denominator
        b = ((cy-ay)*(x-cx)+(ax-cx)*(y-cy))/denominator
        c = 1-a-b
        # Consistent half-open edge coverage avoids alpha seams between adjacent triangles.
        oriented = triangle[[0, 1, 2] if denominator > 0 else [0, 2, 1], :2]
        mask = np.ones(x.shape, dtype=bool)
        for start, end in zip(oriented, np.roll(oriented, -1, axis=0)):
            dx, dy = end-start
            edge = dx*(y-start[1])-dy*(x-start[0])
            inclusive = dy < 0 or (dy == 0 and dx > 0)
            mask &= (edge > 0) | ((edge == 0) & inclusive)
        if not mask.any():
            continue
        weights = np.stack([a, b, c], axis=-1)
        uv = weights @ uvs[index]
        vertex_color = weights @ colors[index]
        world = triangles[index]
        normal = np.cross(world[1]-world[0], world[2]-world[0])
        normal /= max(np.linalg.norm(normal), 1e-10)
        rgb, alpha = shade(uv, normal, vertex_color, time, materials[index])
        rgb = np.broadcast_to(np.asarray(rgb, dtype=float), x.shape+(3,))
        alpha = np.broadcast_to(np.asarray(alpha, dtype=float), x.shape)
        if not np.isfinite(rgb[mask]).all() or not np.isfinite(alpha[mask]).all():
            raise ValueError("Shader adapter returned non-finite visible output")
        alpha = np.clip(alpha, 0, 1)[..., None]
        region = canvas[y0:y1+1, x0:x1+1]
        blended = rgb*alpha + region*(1-alpha)
        region[mask] = blended[mask]
    linear = np.clip(canvas, 0, 1)
    srgb = np.where(linear <= .0031308, linear*12.92, 1.055*linear**(1/2.4)-.055)
    image = Image.fromarray(np.rint(srgb*255).astype(np.uint8))
    return image.resize((width, height), Image.Resampling.LANCZOS) if samples > 1 else image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, required=True)
    parser.add_argument("--shader", type=Path, required=True, help="Trusted task-authored Python adapter")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--width", type=int, default=660)
    parser.add_argument("--height", type=int, default=520)
    parser.add_argument("--pitch", type=float, default=45)
    parser.add_argument("--yaw", type=float, default=0)
    parser.add_argument("--time", type=float, default=0)
    parser.add_argument("--center", type=float, nargs=3)
    parser.add_argument("--span", type=float)
    parser.add_argument("--samples", type=int, default=2)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("vfx_preview_adapter", args.shader)
    adapter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adapter)
    image = render(json.loads(args.scene.read_text()), adapter.shade,
                   width=args.width, height=args.height, pitch=args.pitch, yaw=args.yaw,
                   time=args.time, center=args.center, span=args.span, samples=args.samples)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(args.output.resolve())


if __name__ == "__main__":
    main()
