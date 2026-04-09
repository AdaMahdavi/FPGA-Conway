//for some reason I h

`timescale 1ns / 1ps
`default_nettype none

module tbvga_bram;

    reg      clk_150   =   0;
    reg      clk_25    =   0;
    reg      areset    =   1;

    wire    [9:0]     xpixel;
    wire    [8:0]     ypixel;
    wire          draw_pixel;
    wire              h_sync;
    wire              v_sync;
    wire             rd_data;


    //--- clk1: ~150MHz

    always #3.3 clk_150 = ~clk_150;

    //--- clk2: ~25MHz

    always #20  clk_25  =  ~clk_25;


    VGA_Block vga (
        .vga_clk           (clk),
        .areset         (areset),
        .xpixel         (xpixel),
        .ypixel         (ypixel),
        .draw_pixel (draw_pixel),
        .h_sync         (h_sync),
        .v_sync         (v_sync)
    );

    dp_bram bram (
        .clk               (clk),
        .we               (1'b0),
        .wr_x            (10'b0), 
        .wr_y             (9'b0),
        .wr_data          (1'b0),
        .rd_x           (xpixel),
        .rd_y           (ypixel),
        .rd_data       (rd_data)
    );

    initial begin

        repeat(4) @(posedge clk);
        areset = 0;

    end

    //--- Track scan-order pixel index (accounts for 1-cycle BRAM latency:
    //--- rd_data at posedge N reflects the address presented at posedge N-1,
    //--- so we lag the pixel counter by 1 cycle to get the right expected value)

    integer scan_idx      = -1;   // -1 = waiting for first active pixel
    integer scan_idx_d    = -1;   // 1-cycle delayed → matches rd_data
    reg     draw_pixel_d  =  0;
    reg     [9:0]     xpixel_d;
    reg     [8:0]     ypixel_d;


    always @(posedge clk) begin

        draw_pixel_d <= draw_pixel;
        xpixel_d     <=     xpixel;
        ypixel_d     <=     ypixel;

        if (draw_pixel)
            scan_idx <= (scan_idx == -1) ? 0 : scan_idx + 1;

        scan_idx_d <= scan_idx;

    end

    // ------------------------------
    // verification + display
    // ------------------------------
    integer pass_cnt    = 0;
    integer fail_cnt    = 0;
    integer print_cnt   = 0;       // print first 20 active pixels
    integer fail_shown  = 0;      // cap fail prints at 10

    always @(posedge clk) begin
        if (draw_pixel_d && scan_idx_d >= 0) begin

            // expected: 1 every 3rd pixel in scan order
            automatic bit exp = (scan_idx_d % 3 == 0) ? 1'b1 : 1'b0;

            if (print_cnt < 20) begin
                $display("pixel(%3d,%3d)  scan=%6d  rd_data=%b  exp=%b  %s",
                    xpixel_d, ypixel_d, scan_idx_d,
                    rd_data, exp,
                    (rd_data === exp) ? "ok" : "FAIL ***");
                print_cnt = print_cnt + 1;
            end

            if (rd_data === exp)
                pass_cnt = pass_cnt + 1;
            else begin
                fail_cnt = fail_cnt + 1;
                if (fail_shown < 10) begin
                    $display("  FAIL pixel(%3d,%3d) scan=%6d got=%b exp=%b",
                        xpixel_d, ypixel_d, scan_idx_d, rd_data, exp);
                    fail_shown = fail_shown + 1;
                end
            end
        end
    end

    // ------------------------------
    // run 2 full frames & report
    // ------------------------------
    initial begin
        $dumpfile("tb_vga_bram.vcd");
        $dumpvars(0, tb_vga_bram);
        #(800*525*2*7);
        $display("----------------------------------");
        $display("PASS: %0d  FAIL: %0d  TOTAL: %0d", pass_cnt, fail_cnt, pass_cnt+fail_cnt);
        $display("----------------------------------");
        $finish;
    end

endmodule
