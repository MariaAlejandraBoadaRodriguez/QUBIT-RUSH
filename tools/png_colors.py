#!/usr/bin/env python3
"""Checks that a screenshot actually rendered the UI (pure Python, no PIL).

  png_colors.py <file.png> <hex>:<min_fraction> [<hex>:<min_fraction> ...]

Each colour must cover at least min_fraction of the pixels (within a small
tolerance). Exit 1 otherwise. Supports 8-bit RGB/RGBA non-interlaced PNGs,
which is what `adb exec-out screencap -p` produces.
"""
import struct, sys, zlib


def read_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        ln, typ = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
            if depth != 8 or ctype not in (2, 6) or inter:
                raise ValueError("unsupported PNG format")
            bpp = 3 if ctype == 2 else 4
        elif typ == b"IDAT":
            idat += body
        pos += 12 + ln
    raw, stride = zlib.decompress(idat), w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b, c = prev[x], prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def main():
    w, h, bpp, rows = read_png(sys.argv[1])
    targets = []
    for spec in sys.argv[2:]:
        col, frac = spec.split(":")
        targets.append((tuple(int(col[k:k + 2], 16) for k in (0, 2, 4)), float(frac), col))
    counts, total = [0] * len(targets), 0
    for r in rows[::4]:                      # sample every 4th row/column
        for x in range(0, w * bpp, bpp * 4):
            px = r[x:x + 3]
            total += 1
            for k, (t, _, _) in enumerate(targets):
                if abs(px[0] - t[0]) <= 12 and abs(px[1] - t[1]) <= 12 and abs(px[2] - t[2]) <= 12:
                    counts[k] += 1
    ok = True
    for (t, frac, name), n in zip(targets, counts):
        got = n / max(total, 1)
        good = got >= frac
        ok &= good
        print(f"{sys.argv[1]}: #{name} {got:.4f} (need >= {frac}) {'OK' if good else 'MISSING'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
