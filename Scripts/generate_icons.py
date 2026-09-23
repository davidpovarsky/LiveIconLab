#!/usr/bin/env python3
import math
import struct
import sys
import zlib
from pathlib import Path

SIZES = {
    "Icon-20@2x.png": 40,
    "Icon-29@2x.png": 58,
    "Icon-40@2x.png": 80,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
    "Icon-1024.png": 1024,
}

def chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )

def write_png(path: Path, size: int) -> None:
    # Simple opaque placeholder icon. SpringBoard live-icon rendering will replace
    # its visual content during the actual experiment.
    rows = []
    cx = cy = (size - 1) / 2.0
    radius = size * 0.30
    hand_width = max(1, int(size * 0.028))

    for y in range(size):
        row = bytearray()
        for x in range(size):
            # Deep blue background.
            r, g, b, a = 32, 66, 170, 255

            # White clock face.
            dx = x - cx
            dy = y - cy
            distance = math.sqrt(dx * dx + dy * dy)
            if distance <= radius:
                r, g, b = 248, 248, 250

            # Hour hand: 12 -> 3 direction.
            if abs(y - cy) <= hand_width and cx <= x <= cx + radius * 0.58:
                r, g, b = 28, 28, 30

            # Minute hand: straight up.
            if abs(x - cx) <= hand_width and cy - radius * 0.68 <= y <= cy:
                r, g, b = 28, 28, 30

            # Red second hand.
            if abs(x - cx) <= max(1, hand_width // 2) and cy <= y <= cy + radius * 0.72:
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

    for name, size in SIZES.items():
        path = output / name
        write_png(path, size)
        print(f"generated {path} ({size}x{size})")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
