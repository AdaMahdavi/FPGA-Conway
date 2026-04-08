# FPGA Implementation of Conway's Game of Life

Conway's Game of Life on an FPGA is kind of a cliché project. I first came across it while going through [HDLBits' problem on it](https://hdlbits.01xz.net/wiki/Conwaylife); being the second to last problem I solved before completing my HDLBits run, and like many taking amusement in the vastness of possibilities you can achieve with a single line of logic: `next = (sum == 3) || (center && sum == 2)`, I wanted to try bringing it to life.

## Some Interesting Demos

![pufferfish_breeder](pufferfish_breeder.gif)
![random_seed](random_seed.gif)
![reactors](reactors.gif)
---

Something that stood out to me was that most implementations I came across didn't allocate the full VGA frame; they either used a scaled-up canvas, rendering larger blocks instead of pixel-wide cells. The simple nature of the game logic is probably a definitive factor in why not many go as far as a detailed full-resolution implementation. But I thought starting with the game logic alone and figuring out the architecture around it would be far more interesting than picking an existing hierarchy with predefined dataflow and memory management.

I started knowing nothing but what the game logic was meant to achieve. Everything else was something I learned along the way. The biggest challenge was certainly figuring out memory hierarchy; the final 3-buffer BRAM implementation ended up at 96% memory utilization. A very tight fit, but one that forced me to get creative in ways that would've been pretty straightforward on a more resourceful board.

**Board:** Digilent Basys3 (Xilinx Artix-7 XC7A35T)  
**VGA Display:** 640×480 @ 59.5Hz

---

## Conway's Game of Life and other Cellular Automata:  How does it all work?

Cellular automata follow a simple premise: the next state of each cell depends solely on the state of its neighbors in the previous generation. Game of Life in particular follows this rule:

![Conway rule diagram](conway_rule.png)

![example animation](gol_example_animation)

[Wikipedia]( https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) and various other sources go deep on the interesting patterns and behavior.

From a hardware standpoint, it's clear what the system needs to do: for every cell in the grid, read the current state of that cell and its 8 neighbors, evaluate the next state based on how many neighbors are alive, and write the result to next_state_bram. The catch is doing that for all 307,200 cells within a single VGA frame. At 60Hz, that's a 16.8ms window to compute and transfer every cell's next state before the display starts scanning the next frame. 

---

## Architecture

![System-level block design](architecture_bd.png)

### System Overview

- **clk_wiz_0** —> PLL which takes the onboard 100MHz crystal oscillator and drives two clocks: 150MHz and 25MHz.
- **Game Logic** —> Calculate next state of cells; reads cells from current_state_bram one per cycle, writes results to next_state_bram.
- **next_state_bram** —> where game logic writes to, where mid-game transfer reads from.
- **current_state_bram** —> the shared middle ground; game logic reads it at 150MHz, mid-game transfer updates it at 150MHz once calculations are done.
- **mid-game transfer** —> fires when copy_start goes high; copies next_state into current_state and vram so the display has updated data once it returns to top left corner of the screen.
- **VRAM** —> what VGA controller reads from and displays to screen; isolated from anything game logic touches.
- **VGA Controller** —> drives the display, but also acts as system master; it's the only module that knows where we are in the frame, so it's the one deciding when game logic fires and when transfer starts.

The architecture revolves around three fixed-role BRAMs and a clean separation of concerns between display and compute.
next_state_bram is where game logic writes. current_state_bram is what gets displayed. vram is what the VGA controller reads from directly. Game logic never touches vram, and the VGA controller never touches next_state. The only module that bridges them is mid-game transfer; which reads from next_state, writes to current_state and vram simultaneously once copy_start goes high, and that's its entire job.
There's no buffer swap. The roles are fixed. Mid-game transfer is what moves state forward and replaces swapping logic. 

The VGA controller is the primary driver of the whole system: both game_start and copy_start come from it. As in, game logic is designed to be a pure compute process, instant-fire, doing nothing but calculating next states as fast as possible. The VGA controller is the only module that knows precisely where we are in VGA frame, making it a better fit choice for controlling primary control signals. It knows when a valid display frame is starting, when is best to start updating vram, and which operations to fire at each of those moments. 


The one thing this introduces is a dual-clock situation on VRAM; mid-game transfer writes to it at 150MHz while the VGA-adjacent path reads from it at 25MHz. The BRAM's dual-port architecture handles the clock domain crossing internally, and the row 432 timing guarantee ensures the write pointer never catches the read pointer, while never falling behind on updating the VRAM before VGA pointer returns to top left. I have put a more precise explanation of this [here](TIMING.md). 


###An attempt at Otimizing Bandwidth: Reusing Neighbors
![Neighbor reuse via sliding window for first three cell calculations](sliding_read_window.png)

A brute-force implementation would read all 8 neighbors per cell, which either increases bandwidth requirements or forces more complex multi-cell computation. Besides, if 9 reads are required per cell (accounting for 1-cycle BRAM read latency) plus 1 cycle for writing next state, we're burning 10 cycles for a clock that needs to stay on par with the VGA clock (25MHz); meaning BRAM reads and writes would need to run at at least 250MHz.

My first approach was increasing memory bandwidth: reading 32 bits per turn, storing them in a shift register across a few read cycles, then calculating next state for multiple cells at once. That introduced its own share of non-determinism. The edge cases needed to accurately capture all neighbors for boundary cells (which require wrap-around) multiplied quickly, and verification got trickier since reads and writes would've required different frequencies or extra logic to prevent race conditions; either re-writing unread state cells or reading un-updated memory.

I decided serially reading neighbors would inevitably be the most predictable and robust approach. But we can still optimize reading logic without touching bandwidth, by reusing previously fetched neighbors.

The key insight: we only truly need to read all 9 cells for cells on the left edge of the memory matrix. Any cell to the right shares 6 neighbors with the previous cell (reading left to right, `(y,x) → (y,x+1)`):

- For the first cell in a row, all 8 neighbors are read fresh
- For each subsequent cell, 6 neighbors are reused
- Only 3 new neighbor values are fetched

This reduces memory reads from 9 to 3 per cell; what makes a fully pipelined, sustained update rate possible on limited BRAM. The reduction from 9 to 3 gave a lot of freedom in defining the update window: left-edge cells take 10 cycles, all others take 6. Since we need to keep up with the 25MHz VGA clock; 25 × 6 = 150MHz became the finalized system clock.

### More Considerations on Timing: Transfer Overlap and Collision Avoidance

Took a little math to confirm we can get all state calculations done within a VGA frame. As a result, mid-game transfer starts copying `next_state_bram` onto `vga_bram` once VGA starts scanning row 432. There were some interesting calculations involved in deriving the valid interval and proving no read/write collision can occur; I've put the full breakdown in [TIMING.md](TIMING.md).

### VGA Controller

The VGA controller is written entirely from scratch in Verilog. It generates standard 640×480 @ 60Hz timing (25.175MHz pixel clock via `clk_wiz_0`), with separate modules for horizontal and vertical sync generation, pixel coordinate tracking, and display output. The pixel clock is derived from the onboard 100MHz oscillator using a Vivado clocking wizard IP.

I assume many are familiar with VGA control architecture, but if that's of any interest, there's a separate breakdown [here](VGA.md).

---

## Repository Structure

```
FPGA-Conway/
├── constrs/
│   └── const.xdc               # Basys3 pin constraints (VGA, clock)
├── patterns/                   # Conway pattern initial states as .coe files
│   ├── glider.coe
│   ├── puffer_engine.coe
│   └── ...
├── scripts/
│   ├── build.tcl               # Vivado project rebuild script
│   └── rle_to_coe.py           # Utility: convert .rle patterns to .coe
├── sim/
│   ├── dp_bram_tb.v            # BRAM read/write testbench
│   ├── top_conway_tb.v         # Top-level integration testbench
│   └── vga_bram_tb.sv          # VGA + BRAM pixel output testbench
└── srcs/
    ├── Conway_gol/
    │   ├── conway_logic.sv       # GOL pipeline engine
    │   ├── conway_top_wrapper.sv # Top-level: wires GOL, VGA, BRAMs together
    │   ├── conway_vga.sv         # GOL-to-VGA control logic
    │   ├── copy_bram.sv          # Frame copy controller (next_state → vga_bram)
    │   └── dualp_bram.sv         # Dual-port BRAM wrapper
    ├── VGA_controller/
    │   ├── control_VGA.v         # VGA output controller
    │   ├── display_gen.v         # Pixel data → RGB output
    │   ├── display_test_top.v    # Standalone VGA test top (no GOL)
    │   ├── horizontal_counter.v  # Horizontal pixel counter
    │   ├── hsync_generator.v     # Hsync pulse generator
    │   ├── vertical_counter.v    # Vertical line counter
    │   ├── vsync_generator.v     # Vsync pulse generator
    │   └── xypixel_generator.v   # Active pixel coordinate generator
    └── IP/
        ├── blk_mem_gen_0/        # Block Memory Generator (dual-port BRAM IP)
        └── clk_wiz_0/            # Clock Wizard (100MHz → 25.175MHz pixel clock)
```

---

## Building

### Prerequisites

- Vivado 2024.2 (or compatible; update the version in the tcl script if different)
- Basys3 board (part: XC7A35T)

### Rebuild Project

```bash
vivado -mode batch -source scripts/build.tcl
```

This recreates the full Vivado project from scratch. Open the generated project, run synthesis and implementation, and program the board.

### Loading a Pattern

The active pattern is set by the `.coe` file referenced in `blk_mem_gen_0`. To swap patterns, re-customize the IP in Vivado, point it to a different `.coe` file in `patterns/`, and re-run synthesis.

![Configuring memory IP to load coefficient files](bram_load_coe.png)

### Adding Your Own Pattern

Patterns are standard `.rle` files converted to `.coe` using the included script:

```bash
python scripts/rle_to_coe.py your_pattern.rle patterns/your_pattern.coe
```

There are many great sites to explore interesting patterns; I enjoyed using https://copy.sh/life/examples/ and https://golly.sourceforge.io/webapp/golly.html. You can first simulate a pattern in Golly, use the Python script to convert it to the appropriate memory format, then load it onto BRAM as explained above.

Worth reading: a note on memory mapping [here](MEMORY.md).

---

## Areas for Improvement and What Might Be Worth Exploring Further

**Colors:** there are some very interesting extensions to GOL that can generate colored life-likes. Thermal maps would look pretty interesting, but those were outside the scope of this project.

**Redundant memory mapping:** as mentioned before, I don't use all the cells in the 2^19 wide BRAMs across the 3 buffering stages. For more readable game logic, I generate valid addresses as `{9 bits for y, 10 bits for x}`; but the VGA display frame only covers `0 < y < 480, 0 < x < 640`, so we're effectively using 480 × 640 = 307,200 cells out of 524,288 bits occupied. Was the trade-off worth it? Considering how much it simplified memory mapping and address management, yes. Is it optimal? Definitely not.

**Reset strategy:** there's an async reset button, but it doesn't reset memory; it just resets the VGA controller and game logic. The bigger issue is the inability to reload an initial state without modifying the coefficient files loaded onto BRAM and regenerating the bitstream. Memory was already a significant bottleneck; we're occupying 48 of the 50 available BRAM tiles on the Basys3.

![Resource utilization](utility.png)

The only real counterpart would've been using LUT-based SRAM to store one or two additional configurations using leftover resources, but it didn't appeal much. A more rational extension would simply be moving to a board better suited for fitting multiple configurations, with more memory available.

---

## License

MIT