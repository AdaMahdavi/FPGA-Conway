# Memory Mapping

## Flat Addressing with Empty Bits

Each BRAM in this project is configured as 2^19 = 524,288 entries deep, 1 bit wide. But the actual valid address space is only 480 × 640 = 307,200 entries, the rest sit empty.

The reason is address structure. Rather than doing any fancy packing, addresses are laid out as:

```
bram_addr[18:0] = {y_addr[8:0], x_addr[9:0]}
```

9 bits for y, 10 bits for x. Clean, readable, trivial to decode. The downside is that x only ever goes up to 639 (not 1023) and y only up to 479 (not 511), so a chunk of the address space is permanently unused. 

Is it optimal? No. Does it make every single piece of address logic in the project significantly simpler? Yes. Given that memory management was already the hardest part of this build, that trade-off was absolutely worth it.

---

## Why the Python Script Isn't Just a Format Converter

Most RLE-to-COE scripts you'll find online do a straight sequential dump: read the pattern, write bits in order. That doesn't work here, because VIVADO's BRAM IP initializes memory by address; keep in mind our addresses aren't sequential by pixel order, they're structured as `{y, x}` masks.

So the script has to do two things: parse the RLE pattern, and then place each cell at the correct BRAM address based on its `(x, y)` coordinate rather than its position in the file.

```python
bram_addr = (y << 10) | x
```

It also handles centering the pattern on the 640×480 canvas using fixed offsets:

```python
OFF_X, OFF_Y = 200, 150
```

So whatever pattern you load ends up roughly centered on screen rather than crammed into the top-left corner.

The full script with inline comments can be found here. 


To use it on your own pattern:

```bash
python scripts/rle_to_coe.py your_pattern.rle patterns/your_pattern.coe
```

Then load the generated `.coe` file into `blk_mem_gen_0` via the IP customization window in Vivado and re-run synthesis.