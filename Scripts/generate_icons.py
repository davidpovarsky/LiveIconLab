#!/usr/bin/env python3
import math
import struct
import sys
import zlib
from pathlib import Path

PRIMARY_SIZES = {
    "Icon-20@2x.png": 40,
    "Icon-29@2x.png": 58,
    "Icon-40@2x.png": 80,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
    "Icon-1024.png": 1024,
}

ALTERNATE_SIZES = {
    "20@2x": 40,
    "29@2x": 58,
    "40@2x": 80,
    "76": 76,
    "76@2x": 152,
    "83.5@2x": 167,
}

FRAME_COUNT = 12

def chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )

def point_segment_distance(px, py, ax, ay, bx, by):
    abx = bx - ax
    aby = by - ay
    apx = px - ax
    apy = py - ay
    denom = abx * abx + aby * aby
    if denom == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, (apx * abx + apy * aby) / denom))
    cx = ax + t * abx
    cy = ay + t * aby
    return math.hypot(px - cx, py - cy)

def write_clock_png(path: Path, size: int, frame: int = 0) -> None:
    rows = []
    cx = cy = (size - 1) / 2.0
    radius = size * 0.34
    thick = max(1.0, size * 0.021)
    second_thick = max(1.0, size * 0.011)

    second_angle = -math.pi / 2 + (2 * math.pi * frame / FRAME_COUNT)
    sx = cx + math.cos(second_angle) * radius * 0.83
    sy = cy + math.sin(second_angle) * radius * 0.83

    # Fixed hour/minute hands make movement of the red second hand obvious.
    hour_angle = -math.pi / 2 + math.radians(70)
    minute_angle = -math.pi / 2 + math.radians(210)
    hx = cx + math.cos(hour_angle) * radius * 0.46
    hy = cy + math.sin(hour_angle) * radius * 0.46
    mx = cx + math.cos(minute_angle) * radius * 0.67
    my = cy + math.sin(minute_angle) * radius * 0.67

    for y in range(size):
        row = bytearray()
        for x in range(size):
            r, g, b, a = 32, 66, 170, 255

            d = math.hypot(x - cx, y - cy)
            if d <= radius:
                r, g, b = 248, 248, 250

            # Hour markers.
            marker = False
            for index in range(12):
                angle = -math.pi / 2 + (2 * math.pi * index / 12)
                px = cx + math.cos(angle) * radius * 0.81
                py = cy + math.sin(angle) * radius * 0.81
                if math.hypot(x - px, y - py) <= max(1.0, size * 0.012):
                    marker = True
                    break
            if marker:
                r, g, b = 45, 45, 48

            if point_segment_distance(x, y, cx, cy, hx, hy) <= thick:
                r, g, b = 28, 28, 30
            if point_segment_distance(x, y, cx, cy, mx, my) <= thick:
                r, g, b = 28, 28, 30
            if point_segment_distance(x, y, cx, cy, sx, sy) <= second_thick:
                r, g, b = 230, 52, 70

            if math.hypot(x - cx, y - cy) <= max(1.0, size * 0.025):
                r, g, b = 230, 52, 70

            row.extend((r, g, b, a))
        rows.append(b"\x00" + bytes(row))

    raw = b"".join(rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)

def main() -> int:
    if len(sys.argv) != 2:
        print("usage: generate_icons.py <output-directory>", file=sys.stderr)
        return 2

    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)

    for name, size in PRIMARY_SIZES.items():
        path = output / name
        write_clock_png(path, size, frame=0)
        print(f"generated {path} ({size}x{size})")

    for frame in range(FRAME_COUNT):
        for suffix, size in ALTERNATE_SIZES.items():
            name = f"ClockFrame{frame:02d}-{suffix}.png"
            path = output / name
            write_clock_png(path, size, frame=frame)
            print(f"generated {path} ({size}x{size})")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
