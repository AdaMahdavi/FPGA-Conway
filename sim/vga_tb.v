`timescale 1ns / 1ps

module vga_tb;

    // Parameters (matching VGA)
    localparam VD          = 480;
    localparam V_BP        =  33;
    localparam V_FP        =  10;
    localparam VR          =   2;
    localparam HD          = 640;
    localparam H_BP        =  48;
    localparam H_FP        =  16;
    localparam HR          =  96;
    localparam LINE_LIMIT  = 800;
    localparam FRAME_LIMIT = 525;

    // 25 MHz VGA pixel clock → 40ns period;
    localparam CLK_PERIOD  =  40;

    reg  vga_clk   = 0;
    reg  areset    = 1;

    wire [$clog2(LINE_LIMIT) -1:0]  xpixel;
    wire [$clog2(FRAME_LIMIT)-1:0]  ypixel;

    wire    draw_pixel;
    wire        h_sync;
    wire        v_sync;

    
//--- DUT instantiation
   
    VGA_Block #(
        .VD                   (VD), 
        .V_BP               (V_BP), 
        .V_FP               (V_FP), 
        .VR                   (VR),
        .HD                   (HD), 
        .H_BP               (H_BP), 
        .H_FP               (H_FP), 
        .HR                   (HR),
        .LINE_LIMIT   (LINE_LIMIT), 
        .FRAME_LIMIT (FRAME_LIMIT)
    ) dut (
        .vga_clk         (vga_clk),
        .areset           (areset),
        .xpixel           (xpixel),
        .ypixel           (ypixel),
        .draw_pixel   (draw_pixel),
        .h_sync           (h_sync),
        .v_sync           (v_sync)
    );

    //--- clk gen

    always #(CLK_PERIOD/2) vga_clk = ~vga_clk;


    integer     h_sync_fall_cycle;
    integer    h_sync_pulse_width;
    integer     v_sync_fall_cycle;
    integer    v_sync_pulse_width;
    integer           cycle_count;
    integer           error_count;

    integer   draw_outside_active; //--- should never happen
    integer          h_sync_count;
    integer          v_sync_count;

    //--- cycle counter (observing frames for debug)
    always @(posedge vga_clk) cycle_count = cycle_count + 1;

    //--- Check: draw_pixel never high outside active area


    //--- VCD dump for waveform viewing
    initial begin
        $dumpfile("vga_tb.vcd");
        $dumpvars(0, vga_tb);
    end


    always @(posedge vga_clk) begin
        if (!areset && draw_pixel) begin
            if (xpixel >= HD || ypixel >= VD) begin
                $display("ERROR @ cycle %0d: draw_pixel HIGH outside active area! xpixel=%0d ypixel=%0d",
                          cycle_count, xpixel, ypixel);
                error_count = error_count + 1;
            end
        end
    end

    
    //--- Measure h_sync pulse width (??)
    always @(negedge h_sync) begin
        h_sync_fall_cycle = cycle_count;
        h_sync_count = h_sync_count + 1;
    end

    always @(posedge h_sync) begin
        if (h_sync_fall_cycle > 0) begin
            h_sync_pulse_width = cycle_count - h_sync_fall_cycle;
            if (h_sync_pulse_width !== HR) begin
                $display("ERROR: h_sync pulse width = %0d cycles, expected %0d",
                          h_sync_pulse_width, HR);
                error_count = error_count + 1;
            end
        end
    end

    //--- Measure v_sync pulse width (in lines) (I thought I might be missing sync pulses)
    always @(negedge v_sync) begin
        v_sync_fall_cycle = cycle_count;
        v_sync_count = v_sync_count + 1;
    end

    always @(posedge v_sync) begin
        if (v_sync_fall_cycle > 0) begin
            v_sync_pulse_width = (cycle_count - v_sync_fall_cycle) / LINE_LIMIT;
            if (v_sync_pulse_width !== VR) begin
                $display("ERROR: v_sync pulse width = %0d lines, expected %0d",
                          v_sync_pulse_width, VR);
                error_count = error_count + 1;
            end
        end
    end

    
    //--- main test sequence
    integer expected_hsync_per_frame;
    integer expected_vsync_per_run;

    initial begin
        //--- init
        cycle_count          = 0;
        error_count          = 0;
        h_sync_fall_cycle    = 0;
        v_sync_fall_cycle    = 0;
        h_sync_count         = 0;
        v_sync_count         = 0;
        draw_outside_active  = 0;

        $display("=== VGA_Block Testbench Start ===");
        $display("Resolution: %0dx%0d | Line: %0d | Frame: %0d",
                  HD, VD, LINE_LIMIT, FRAME_LIMIT);


        // --- hold reset
    
        areset = 1;
        repeat(5) @(posedge vga_clk);
        areset = 0;
        $display("[%0t] Reset released", $time);

        // ---- Run for 2 full frames
        // 1 frame = LINE_LIMIT * FRAME_LIMIT cycles = 800 * 525 = 420,000 cycles
        repeat(LINE_LIMIT * FRAME_LIMIT * 2) @(posedge vga_clk);

        // ---- Check h_sync count (should be FRAME_LIMIT per frame)
        expected_hsync_per_frame = FRAME_LIMIT * 2; // 2 frames
        if (h_sync_count < expected_hsync_per_frame - 2 ||   // -2 tolerance for reset boundary
            h_sync_count > expected_hsync_per_frame + 2) begin
            $display("ERROR: Got %0d h_sync pulses, expected ~%0d",
                      h_sync_count, expected_hsync_per_frame);
            error_count = error_count + 1;
        end else begin
            $display("PASS: h_sync count = %0d (expected ~%0d)",
                      h_sync_count, expected_hsync_per_frame);
        end

        // ---- Check v_sync count (should be 2 for 2 frames) 
        if (v_sync_count < 1 || v_sync_count > 3) begin
            $display("ERROR: Got %0d v_sync pulses, expected ~2", v_sync_count);
            error_count = error_count + 1;
        end else begin
            $display("PASS: v_sync count = %0d", v_sync_count);
        end

        // ---- Check xpixel/ypixel ranges stayed in bounds 
        // (covered by the always block above, just report)
        if (draw_outside_active > 0)
            $display("ERROR: draw_pixel asserted outside active area %0d times",
                      draw_outside_active);

        // ---- final report
        $display("=== Total cycles simulated: %0d ===", cycle_count);
        if (error_count == 0)
            $display("ALL CHECKS PASSED");
        else
            $display("FAILED: %0d error(s) found", error_count);

        $finish;
    end


endmodule