# This is a tiny custom scripts for translating rle maps meant for Game of Life,
# which can be found from various resources across internet, into proper .coe files suited for VIVADO's BRAM IP,
#note that this isn't just a format conversion, but also a dedicated address mapping to match addressing structure of this project:
# bram_addr [18:0] = {y_addr[8:0], x_addr[9:0]};
# which means, although bram ip is configured to have 2^19 = 524,288 entries, only 480 x 640 = 307,200 are valid addresses. 
# this file ensures each coordinate read from .rle file is mapped to appropriate location in bram instead of blindly copying data in order.

# RLE → COE for this project (1024x512 BRAM, 640x480 valid window)

import re

W, H = 1024, 512
VW, VH = 640, 480

# Offset for placing coordinates around a center point
OFF_X, OFF_Y = 200, 150


def parse_rle(text):
    data = "".join(
        l.strip() for l in text.splitlines()
        if l and not l.startswith("#") and not l.startswith("x")
    )

    rows, cur, num = [], [], ""

    for ch in data:
        if ch.isdigit():
            num += ch
        elif ch in "bo":
            n = int(num) if num else 1
            cur += ["1" if ch == "o" else "0"] * n
            num = ""
        elif ch == "$":
            rows.append("".join(cur))
            cur = []
            num = ""
        elif ch == "!":
            rows.append("".join(cur))
            break

    w = max(len(r) for r in rows)
    return [r.ljust(w, "0") for r in rows]


def rle_to_coe(rle_path, coe_path):
    rows = parse_rle(open(rle_path).read())

    grid = [["0"] * W for _ in range(H)]

    for y in range(len(rows)):
        for x in range(len(rows[0])):
            yy = OFF_Y + y
            xx = OFF_X + x

            if 0 <= xx < VW and 0 <= yy < VH:
                if rows[y][x] == "1":
                    grid[yy][xx] = "1"

    bits = [grid[y][x] for y in range(H) for x in range(W)]

    with open(coe_path, "w") as f:
        # header

        f.write("memory_initialization_radix=2;\n")
        f.write("memory_initialization_vector=\n")

        for i, b in enumerate(bits):
            f.write(b + (";\n" if i == len(bits)-1 else ",\n"))


# run
rle_to_coe("input.rle", "output.coe")