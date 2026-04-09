# Timing Analysis: Transfer overlap and collision avoidance

As discussed, me have the system running 2 different clocks. VGA BRAM having two ports, is being updated and read over two distinct clocks. so an important question is: can we compute all 307,200 next states and transfer them to VRAM within a single VGA frame, without the write pointer ever catching the VGA read pointer mid-transfer? (in other words, how can we ensure we're never over-writing unread cells, or, reading an ooutdated coordinate again?)

The short answer is yes, by starting updates slightly sooner. 

---

## Frame budget

VGA at 60Hz gives us a full frame period of:

```
525 lines × 800 clocks/line = 420,000 pixel clocks @ 25MHz ≈ 16.8ms
```

Compute and transfer costs at 150MHz:

```
Compute:  (10 + 6×639) × 480 = 1,845,120 cycles ≈ 12.3ms
Transfer: 640 × 480           =   307,200 cycles ≈  2.0ms
Total:                                            ≈ 14.3ms
```

14.3ms fits inside 16.8ms. But doing compute then transfer sequentially wastes the slack. Instead, transfer starts mid-frame, once VGA has scanned past row 432, overlapping with the tail end of compute.

---

## Why row 432?

Transfer is triggered by VGA position, not compute. The constraint is simply: remaining VGA time from row R must be enough to complete a full 307,200-cell transfer before the next frame starts.

```
Remaining pixel clocks from row R = (525 − R) × 800
Transfer needs: 307,200 / 6 = 51,200 pixel clock equivalents
(at 150MHz, write clock is 6× faster than pixel clock)

(525 − R) × 800 ≥ 51,200
525 − R ≥ 64
R ≤ 461
```

Any row before 461 is a valid trigger point. Row 432 gives ~29 rows of margin on the late end. Compute finishes well before this point, so there's no risk of transferring stale data.

---

## Guaranteeing no pointer collision

Mid-game transfer writes to VRAM at 150MHz. The VGA controller reads from VRAM at 25MHz. Write is 6× faster than read, so the question is whether the write pointer ever catches the read pointer during transfer.

At row 432, the VGA read pointer is already:

```
432 × 640 = 276,480 addresses into VRAM
```

Write starts at address 0. The gap closes at a net rate of 5 addresses per 25MHz clock (write advances 6, read advances 1 during active pixels):

During the remaining active scan (rows 432 → 480):

```
Total 25MHz clocks: 48 × 800 = 38,400
Gap reduction:      48 × (6×640 − 640) = 48 × 3,200 = 153,600 ... 
```

Wait — VGA only reads during active pixels (640 out of every 800 clocks). So the effective read rate isn't 1 per clock, it's 640/800 of the time. Adjusting:

```
Gap reduction per line = 6×800 (write) − 640 (read) = 4,160 addresses per line
Over 48 lines: 48 × 4,160 = 199,680
Remaining gap: 276,480 − 199,680 = 76,800
```

The gap never reaches zero during active scan. After row 480, VGA enters blanking and stops reading entirely, while write continues until transfer is done. Collision is impossible.

---

## Summary

| | Value |
|---|---|
| Compute time | ~12.3ms |
| Transfer time | ~2.0ms |
| Frame window | ~16.8ms |
| Valid transfer trigger range | rows 0 → 461 |
| Chosen trigger row | 432 |
| Gap at trigger | 276,480 addresses |
| Gap at end of active scan | 76,800 addresses |
| Collision | impossible |

In other words, row 432 is a deliberate pick inside a mathematically derived window, with enough margin on both ends to not have to think about it again.
